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
        
        create_connection = lambda do
          Mysql.new(configuration.host, configuration.username, configuration.password, configuration.database)
        end
        
        # Initialize the connection pool.
        if single_threaded?
          @connection_factory = create_connection
          @active_connection = create_connection[]
        else
          @connections = Support::ConnectionPool.new(&create_connection)
        end
      end
      
      # Yields an available connection. Flushes the connection-pool if
      # the connection returns an error.
      def connection
        
        if single_threaded?
          begin
            # BUG: Single_threaded mode totally breaks shit right now. No real idea why just from
            # eyeballing this. Probably should move this into the SqlAdapter anyways and just
            # force derived adapters to implement a #create_connection() and #close_connection(conn) methods.
            yield(@active_connection)
          rescue Mysql::Error => me
            @configuration.log.fatal(me)
            
            begin
              @active_connection.close
            rescue => se
              @configuration.log.error(se)
            end
            
            @active_connection = @connection_factory[]
          end
        else
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
      end
      
      def execute(*args)
        connection do |db|
          reader = db.query(escape_sql(*args))
          result = yield(reader, reader.fetch_fields.map { |field| field.name })
          reader.free
          result
        end
      end
      
      def query(*args)
        
        execute(*args) do |reader, fields|
          struct = Struct.new(*fields.map { |field| String::memoized_underscore(field).to_sym })
          
          results = []
          
          reader.each do |row|
            results << struct.new(*row)
          end
          results
          
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
            fetch_all(reader).first
          end
             
          def fetch_all(reader)
            load_instances(reader.fetch_fields.map { |field| field.name }, reader)
          end
          
        end
        
      end
      
    end # class MysqlAdapter
    
  end # module Adapters
end # module DataMapper