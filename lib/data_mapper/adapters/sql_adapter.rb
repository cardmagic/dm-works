require 'data_mapper/adapters/abstract_adapter'
require 'data_mapper/adapters/sql/commands/load_command'
require 'data_mapper/adapters/sql/commands/advanced_load_command'
require 'data_mapper/adapters/sql/commands/count_command'
require 'data_mapper/adapters/sql/commands/save_command'
require 'data_mapper/adapters/sql/commands/delete_command'
require 'data_mapper/adapters/sql/commands/table_exists_command'
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
  # The second type provided by the Adapter is a DataMapper::Connection.
  # This allows us to execute queries and return results in a clear and
  # uniform manner we can use throughout the DataMapper.
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
      
    # You must inherit from the SqlAdapter, and implement the
    # required methods to adapt a database library for use with the DataMapper.
    #
    # NOTE: By inheriting from SqlAdapter, you get a copy of all the
    # standard sub-modules (Quoting, Coersion and Queries) in your own Adapter.
    # You can extend and overwrite these copies without affecting the originals.
    class SqlAdapter < AbstractAdapter
      
      FIND_OPTIONS = [
        :select, :offset, :limit, :class, :include, :shallow_include, :reload, :conditions, :order, :intercept_load
      ]
      
      def initialize(configuration)
        super
        
        unless @configuration.single_threaded?
          @connection_pool = Support::ConnectionPool.new { create_connection }
        end
      end
      
      def create_connection
        raise NotImplementedError.new
      end
      
      def close_connection(conn)
        raise NotImplementedError.new
      end
      
      # Yields an available connection. Flushes the connection-pool and reconnects
      # if the connection returns an error.
      def connection
        begin
          # Yield the appropriate connection
          if @configuration.single_threaded?
            yield(@active_connection || @active_connection = create_connection)
          else
            @connection_pool.hold { |active_connection| yield(active_connection) }
          end
        rescue => execution_error
          # Log error on failure
          @configuration.log.error(execution_error)
          
          # Close all open connections, assuming that if one
          # had an error, it's likely due to a lost connection,
          # in which case all connections are likely broken.
          begin
            if @configuration.single_threaded?
              close_connection(@active_connection)
            else
              @connection_pool.available_connections.each do |active_connection|
                close_connection(active_connection)
              end
            end
          rescue => close_connection_error
            # An error on closing the connection is almost expected
            # if the socket is broken.
            @configuration.log.warn(close_connection_error)
          end
          
          # Reopen fresh connections.
          if @configuration.single_threaded?
            @active_connection = create_connection
          else
            @connection_pool.available_connections.clear
          end
          
          raise execution_error
        end
      end
        
      def transaction(&block)
        raise NotImplementedError.new
      end
      
      def execute(*args)
        connection do |db|
          sql = escape_sql(*args)
          log.debug(sql)
          reader = query_returning_reader(db, sql)
          result = yield(reader, count_rows(db, reader))
          free_reader(reader)
          result
        end
      rescue => e
        handle_error(e)
      end
      
      def insert(*args)
        raise NotImplementedError.new
      end
      
      # Must implement! Passes in the result of a query execution and
      # should return an Array of Symbols.
      def fetch_fields(reader)
        raise NotImplementedError.new
      end
      
      def query(*args)
        execute(*args) do |reader,num_rows|
          fields = fetch_fields(reader)

          results = []
          
          if fields.size > 1
            struct = Struct.new(*fields)
          
            reader.each do |row|
              results << struct.new(*row)
            end
          else
            reader.each do |row|
              results << row[0]
            end
          end
          
          results
        end
      end      
      
      def handle_error(error)
        raise error
      end
      
      def schema
        @schema || ( @schema = Mappings::Schema.new(self) )
      end
      
      def table_exists?(name)
        self.class::Commands::TableExistsCommand.new(self, name).call
      end
      
      def delete(klass_or_instance, options = nil)
        self.class::Commands::DeleteCommand.new(self, klass_or_instance, options).call
      end
      
      def save(session, instance)
        self.class::Commands::SaveCommand.new(self, session, instance).call
      end
      
      def load(session, klass, options)
        self.class::Commands::AdvancedLoadCommand.new(self, session, klass, options).call
      end
      
      def count(klass_or_instance, options)
        self.class::Commands::CountCommand.new(self, klass_or_instance, options).call
      end
      
      def table(instance)
        case instance
        when DataMapper::Adapters::Sql::Mappings::Table then instance
        when DataMapper::Base then schema[instance.class]
        when Class, String then schema[instance]
        else raise "Don't know how to map #{instance.inspect} to a table."
        end
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
      # in the SqlAdapter to the inherited class so you don't
      # have to copy and paste large blocks of code from the
      # SqlAdapter.
      # 
      # Basically, when inheriting from the SqlAdapter, you
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
        :decimal => 'decimal'.freeze
      }

      include Sql
      include Quoting
      include Coersion
      
    end # class SqlAdapter
    
  end # module Adapters
end # module DataMapper