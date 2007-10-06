require 'data_mapper/adapters/sql_adapter'

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
      
      def create_connection
        Mysql.new(
          @configuration.host,
          @configuration.username,
          @configuration.password,
          @configuration.database
        )
      end
      
      def close_connection(conn)
        conn.close
      end
      
      def execute(*args)
        connection do |db|
          sql = escape_sql(*args)
          log.debug(sql)
          reader = db.query(sql)
          result = yield(reader, reader.num_rows)
          reader.free
          result
        end
      rescue => e
        handle_error(e)
      end
      
      def fetch_fields(reader)
        reader.fetch_fields.map { |field| Inflector.underscore(field.name).to_sym }
      end
      
      def reflect_columns(table)
        query("SHOW COLUMNS IN ?", table)
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
        
      end
      
    end # class MysqlAdapter
    
  end # module Adapters
end # module DataMapper