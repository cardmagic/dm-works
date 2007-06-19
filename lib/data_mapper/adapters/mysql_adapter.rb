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
      
      # Returns an available connection. Flushes the connection-pool if
      # the connection returns an error.
      def connection
        raise ArgumentError.new('MysqlAdapter#connection requires a block-parameter') unless block_given?
        begin
          @connections.hold { |connection| yield connection }
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

      def type_cast_boolean(value)
        case value
          when TrueClass, FalseClass then value
          when "1", "true", "TRUE" then true
          when "0", nil then false
          else "Can't type-cast #{value.inspect} to a boolean"
        end
      end

      def type_cast_datetime(value)
        case value
          when DateTime then value
          when Date then DateTime.new(value)
          when String then DateTime::parse(value)
          else "Can't type-cast #{value.inspect} to a datetime"
        end
      end
      
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
            results = []
            set = []
            reader.each_hash do |hash|
              results << load(hash, set)
            end
            results
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