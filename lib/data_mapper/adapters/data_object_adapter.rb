require 'data_mapper/adapters/abstract_adapter'
require 'data_mapper/adapters/sql/commands/load_command'
require 'data_mapper/adapters/sql/coersion'
require 'data_mapper/adapters/sql/quoting'
require 'data_mapper/adapters/sql/mappings/schema'
require 'data_mapper/support/connection_pool'

module DataMapper
  
  # An Adapter is really a Factory for three types of object,
  # so they can be selectively sub-classed where needed.
  # 
  # The first type is a Query. The Query is an object describing
  # the database-specific operations we wish to perform, in an
  # abstract manner. For example: While most if not all databases
  # support a mechanism for limiting the size of results returned,
  # some use a "LIMIT" keyword, while others use a "TOP" keyword.
  # We can set a SelectStatement#limit field then, and allow
  # the adapter to override the underlying SQL generated.
  # Refer to DataMapper::Queries.
  #
  # The final type provided is a DataMapper::Transaction.
  # Transactions are duck-typed Connections that span multiple queries.
  #
  # Note: It is assumed that the Adapter implements it's own
  # ConnectionPool if any since some libraries implement their own at
  # a low-level, and it wouldn't make sense to pay a performance
  # cost twice by implementing a secondary pool in the DataMapper itself.
  # If the library being adapted does not provide such functionality,
  # DataMapper::Support::ConnectionPool can be used.
  module Adapters
      
    # You must inherit from the DoAdapter, and implement the
    # required methods to adapt a database library for use with the DataMapper.
    #
    # NOTE: By inheriting from DoAdapter, you get a copy of all the
    # standard sub-modules (Quoting, Coersion and Queries) in your own Adapter.
    # You can extend and overwrite these copies without affecting the originals.
    class DataObjectAdapter < AbstractAdapter
      
      $LOAD_PATH << (DM_PLUGINS_ROOT + '/dataobjects')
      
      FIND_OPTIONS = [
        :select, :offset, :limit, :class, :include, :shallow_include, :reload, :conditions, :order, :intercept_load
      ]
      
      TABLE_QUOTING_CHARACTER = '`'.freeze
      COLUMN_QUOTING_CHARACTER = '`'.freeze
      
      def initialize(configuration)
        super
        @mutex = Mutex.new        
        @connection_pool = Support::ConnectionPool.new { create_connection }
      end
      
      def create_connection
        raise NotImplementedError.new
      end
      
      # Yields an available connection. Flushes the connection-pool and reconnects
      # if the connection returns an error.
      def connection
        begin
          # Yield the appropriate connection
          @connection_pool.hold { |active_connection| yield(active_connection) }
        rescue => execution_error
          # Log error on failure
          @configuration.log.error(execution_error)
          
          # Close all open connections, assuming that if one
          # had an error, it's likely due to a lost connection,
          # in which case all connections are likely broken.
          flush_connections!
          
          raise execution_error
        end
      end
      
      # Close any open connections.
      def flush_connections!
        begin
          @connection_pool.available_connections.each do |active_connection|
            active_connection.close
          end
        rescue => close_connection_error
          # An error on closing the connection is almost expected
          # if the socket is broken.
          @configuration.log.warn(close_connection_error)
        end
        
        # Reopen fresh connections.
        @connection_pool.available_connections.clear
      end
      
      def transaction(&block)
        raise NotImplementedError.new
      end
      
      def execute(*args)
        @mutex.synchronize do
          connection do |db|
            sql = escape_sql(*args)
            log.debug { sql }
          
            command = db.create_command(sql)
          
            if block_given?
              command.execute_reader { |reader| yield(reader) }
            else
              command.execute_non_query
            end
          end
        end
      rescue => e
        handle_error(e)
      end
      
      def query(*args)        
        connection do |db|
          sql = escape_sql(*args)
          log.debug { sql }
        
          command = db.create_command(sql)
        
          command.execute_reader do |reader|
            fields = reader.fields.map { |field| Inflector.underscore(field).to_sym }
            
            results = []

            if fields.size > 1
              struct = Struct.new(*fields)
              
              reader.each do
                results << struct.new(*reader.current_row)
              end
            else
              reader.each do
                results << reader.item(0)
              end
            end

            results            
          end
        end
      end      
      
      def handle_error(error)
        raise error
      end
      
      def schema
        @schema || ( @schema = Mappings::Schema.new(self, @configuration.database) )
      end
      
      def table_exists?(name)
        execute(table(name).to_exists_sql) { |reader| reader.has_rows? }
      end
      
      def truncate(session, name)
        result = execute("TRUNCATE TABLE #{table(name).to_sql}")
        session.identity_map.clear!(name)
        result.to_i > 0
      end
      
      def drop(session, name)
        result = execute("DROP TABLE #{table(name).to_sql}")
        session.identity_map.clear!(name)
        true
      end
      
      def create_table(name)
        execute(table(name).to_create_table_sql); true
      end
      
      def delete(session, instance)
        table = self.table(instance)
        
        if instance.is_a?(Class)
          execute("DELETE FROM #{table.to_sql}")
          session.identity_map.clear!(instance)
        else
          callback(instance, :before_destroy)
          
          if execute("DELETE FROM #{table.to_sql} WHERE #{table.key.to_sql} = #{quote_value(instance.key)}").to_i > 0
            instance.instance_variable_set(:@new_record, true)
            instance.session = session
            instance.original_hashes.clear
            session.identity_map.delete(instance)
            callback(instance, :after_destroy)
          end          
        end
      end
      
      def save(session, instance)
        case instance
        when Class, Mappings::Table then create_table(instance)
        when DataMapper::Base then
          return false unless instance.dirty? && instance.valid?
          
          callback(instance, :before_save)           
          
          # INSERT
          result = if instance.new_record?
            callback(instance, :before_create)

            table = self.table(instance)
            attributes = instance.dirty_attributes
            
            unless attributes.empty?
              attributes[:type] = instance.class.name if table.multi_class?
            
              keys = []
              values = []
              attributes.each_pair do |key, value|
                keys << table[key].to_sql
                values << value
              end
          
              # Formatting is a bit off here, but it looks nicer in the log this way.
              insert_id = execute("INSERT INTO #{table.to_sql} (#{keys.join(', ')}) VALUES (#{values.map { |v| quote_value(v) }.join(', ')})").last_insert_row
              instance.instance_variable_set(:@new_record, false)
              instance.key = insert_id if table.key.serial? && !attributes.include?(table.key.name)
              session.identity_map.set(instance)
              callback(instance, :after_create)
            end
          # UPDATE
          else            
            callback(instance, :before_update)
            
            table = self.table(instance)
            attributes = instance.dirty_attributes
            
            unless attributes.empty?
              sql = "UPDATE " << table.to_sql << " SET "
      
              sql << attributes.map do |key, value|
                "#{table[key].to_sql} = #{quote_value(value)}"
              end.join(', ')
      
              sql << " WHERE #{table.key.to_sql} = " << quote_value(instance.key)
          
              execute(sql).to_i > 0 && callback(instance, :after_update)
            end
          end
          
          instance.attributes.each_pair do |name, value|
            instance.original_hashes[name] = value.hash
          end
          
          instance.loaded_associations.each do |association|
            association.save if association.respond_to?(:save)
          end
          
          instance.session = session
          callback(instance, :after_save)
          result
        end
      rescue => error
        log.error(error)
        raise error
      end
      
      def load(session, klass, options)
        self.class::Commands::LoadCommand.new(self, session, klass, options).call
      end
      
      def count(klass_or_instance, options)
        query("SELECT COUNT(*) AS row_count FROM " + table(klass_or_instance).to_sql).first.to_i
      end
      
      def table(instance)
        case instance
        when DataMapper::Adapters::Sql::Mappings::Table then instance
        when DataMapper::Base then schema[instance.class]
        when Class, String then schema[instance]
        else raise "Don't know how to map #{instance.inspect} to a table."
        end
      end
      
      def callback(instance, callback_name)
        instance.class.callbacks.execute(callback_name, instance)
      end
      
      # Escape a string of SQL with a set of arguments.
      # The first argument is assumed to be the SQL to escape,
      # the remaining arguments (if any) are assumed to be
      # values to escape and interpolate.
      #
      # ==== Examples
      #   escape_sql("SELECT * FROM zoos")
      #   # => "SELECT * FROM zoos"
      # 
      #   escape_sql("SELECT * FROM zoos WHERE name = ?", "Dallas")
      #   # => "SELECT * FROM zoos WHERE name = `Dallas`"
      #
      #   escape_sql("SELECT * FROM zoos WHERE name = ? AND acreage > ?", "Dallas", 40)
      #   # => "SELECT * FROM zoos WHERE name = `Dallas` AND acreage > 40"
      # 
      # ==== Warning
      # This method is meant mostly for adapters that don't support
      # bind-parameters.
      def escape_sql(*args)
        sql = args.shift
      
        unless args.empty?
          sql.gsub!(/\?/) do |x|
            quote_value(args.shift)
          end
        end
        
        sql
      end
      
      # This callback copies and sub-classes modules and classes
      # in the DoAdapter to the inherited class so you don't
      # have to copy and paste large blocks of code from the
      # DoAdapter.
      # 
      # Basically, when inheriting from the DoAdapter, you
      # aren't just inheriting a single class, you're inheriting
      # a whole graph of Types. For convenience.
      def self.inherited(base)
        
        commands = base.const_set('Commands', Module.new)

        Sql::Commands.constants.each do |name|
          commands.const_set(name, Class.new(Sql::Commands.const_get(name)))
        end
        
        mappings = base.const_set('Mappings', Module.new)
        
        Sql::Mappings.constants.each do |name|
          mappings.const_set(name, Class.new(Sql::Mappings.const_get(name)))
        end
        
        base.const_set('TYPES', TYPES.dup)
        base.const_set('FIND_OPTIONS', FIND_OPTIONS.dup)
        
        super
      end
      
      TYPES = {
        :integer => 'int'.freeze,
        :string => 'varchar'.freeze,
        :text => 'text'.freeze,
        :class => 'varchar'.freeze,
        :decimal => 'decimal'.freeze,
        :float => 'float'.freeze,
        :datetime => 'datetime'.freeze,
        :date => 'date'.freeze
      }

      include Sql
      include Quoting
      include Coersion
      
    end # class DoAdapter
    
  end # module Adapters
end # module DataMapper