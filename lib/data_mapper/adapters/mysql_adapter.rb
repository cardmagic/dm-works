require 'data_mapper/adapters/sql_adapter'
require 'data_mapper/support/connection_pool'

begin
  require 'mysql'
rescue LoadError
  STDERR.puts <<-EOS.gsub(/^(\s+)/, '')
    This adapter currently depends on the \"mysql\" gem.
    If some kind soul would like to make it work with
    a pure-ruby version that'd be super spiffy.
  EOS
  
  raise
end

module DataMapper
  module Adapters
    
    class MysqlAdapter < SqlAdapter
      
      def initialize(configuration)
        super
        # Initialize the connection pool.
        @connections = Support::ConnectionPool.new do
          Mysql.new(configuration.host, configuration.username, configuration.password, configuration.database)
        end
      end
      
      # Yields an available connection. Flushes the connection-pool if
      # the connection returns an error.
      def connection
        begin
          @connections.hold { |dbh| yield(dbh) }
        rescue Mysql::Error => me
          
          @configuration.log.fatal(me)
          
          @connections.available_connections.each do |sock|
            begin
              sock.close
            rescue => se
              @configuration.log.error(se)
            end
          end
          
          @connections.available_connections.clear
          raise me
        end
      end
      
      TABLE_QUOTING_CHARACTER = '`'.freeze
      COLUMN_QUOTING_CHARACTER = '`'.freeze
      
      TRUE_ALIASES.unshift('1'.freeze)
      FALSE_ALIASES.unshift('0'.freeze)
      
      module Commands
        
        class TableExistsCommand
          def call
            sql = to_sql
            @adapter.log.debug(sql)
            reader = @adapter.connection { |db| db.query(sql) }
            result = reader.num_rows > 0
            reader.free
            result
          end
        end
        
        class DeleteCommand
          
          def execute(sql)
            @adapter.connection do |db|
              @adapter.log.debug(sql)
              db.query(sql)
              db.affected_rows > 0
            end
          end
          
          def execute_drop(sql)
            @adapter.log.debug(sql)
            @adapter.connection { |db| db.query(sql) }
            true
          end
          
        end
        
        class SaveCommand
          
          def execute_insert(sql)
            @adapter.connection do |db|
              @adapter.log.debug(sql)
              db.query(sql)
              db.insert_id
            end
          end
          
          def execute_update(sql)
            @adapter.connection do |db|
              @adapter.log.debug(sql)
              db.query(sql)
              db.affected_rows > 0
            end
          end
          
          def execute_create_table(sql)
            @adapter.log.debug(sql)
            @adapter.connection { |db| db.query(sql) }
            true
          end
          
        end
        
        class LoadCommand
          def eof?(reader)
            reader.num_rows == 0
          end
          
          def close_reader(reader)
            reader.free
          end
          
          def execute(sql)
            @adapter.log.debug(sql)
            @adapter.connection { |db| db.query(to_sql) }
          end
          
          def fetch_one(reader)
            load(reader.fetch_hash)
          end
             
          def fetch_all(reader)
            
            # instance_class = if type_override = fields.find { |field| field.name == 'type' }
            #   type_name_field_index = fields.index(type_override)
            #   type_name = reader.fetch_row[type_name_field_index]                            
            #   Kernel::const_get(type_name)
            # else
            #   klass
            # end
            
            fields = reader.fetch_fields
            
            table = @adapter[klass]
            
            set = []
            columns = {}
            key_ordinal = nil
            key_column = table.key
            
            fields.each_with_index do |field, i|
              column = table.find_by_column_name(field.name.to_sym)
              key_ordinal = i if field.name.to_s == 'id'
              columns[column] = i
            end
            
            reader.each do |row|
              load_instance(
                create_instance(
                  klass,
                  key_column.type_cast_value(row[key_ordinal])
                ),
                columns,
                row,
                set
              )
            end
            
            set.dup
          end
          
          def load_structs(reader)
            struct = nil
            columns = nil
            results = []
            
            reader.each_hash do |hash|
              if struct.nil?
                columns = hash.keys
                struct = Struct.new(*columns.map { |c| c.to_sym })
              end
              
              results << struct.new(*columns.map { |c| hash[c] })
            end
            
            reader.free
            results
            
          end
        end
        
      end
      
    end # class MysqlAdapter
    
  end # module Adapters
end # module DataMapper