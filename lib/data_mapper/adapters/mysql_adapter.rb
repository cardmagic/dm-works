require 'data_mapper/adapters/sql_adapter'
require 'mysql'

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
      
      def query_returning_reader(db, sql)
        db.query(sql)
      end
      
      def count_rows(db, reader)
        reader.nil? ? db.affected_rows : reader.num_rows
      end
      
      def free_reader(reader)
        reader.free unless reader.nil?
      end
      
      def fetch_fields(reader)
        reader.fetch_fields.map { |field| Inflector.underscore(field.name).to_sym }
      end
      
      TABLE_QUOTING_CHARACTER = '`'.freeze
      COLUMN_QUOTING_CHARACTER = '`'.freeze
      
      def insert(*args)
        connection do |db|
          sql = escape_sql(*args)
          log.debug { sql }
          db.query(sql)
          yield(db.insert_id)
        end
      end
      
    end # class MysqlAdapter
    
  end # module Adapters
end # module DataMapper