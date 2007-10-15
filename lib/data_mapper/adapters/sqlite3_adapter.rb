require 'data_mapper/adapters/sql_adapter'
require 'data_mapper/support/connection_pool'

require 'sqlite3'

module DataMapper
  module Adapters
    
    # Where are the docs on SQLite3? Damnit... http://sqlite-ruby.rubyforge.org
    # is a little confusing when it says it's NOT for sqlite3.
    # And it seems to be missing methods that are obviously in the gem (like #total_changes).
    # Guess I'll peek at the local rdocs when I get some more time to clean this up...
    class Sqlite3Adapter < SqlAdapter
      
      TYPES.merge!({
        :integer => 'INTEGER'.freeze,
        :string => 'TEXT'.freeze,
        :text => 'TEXT'.freeze,
        :class => 'TEXT'.freeze
      })

      TABLE_QUOTING_CHARACTER = '"'.freeze
      COLUMN_QUOTING_CHARACTER = '"'.freeze
      
      def create_connection
        SQLite3::Database.new(@configuration.database)
      end
      
      def close_connection(conn)
        conn.close
      end

      def query_returning_reader(db, sql)
        db.query(sql)
      end
      
      def insert(*args)
        connection do |db|
          sql = escape_sql(*args)
          log.debug { sql }
          db.query(sql)
          yield(db.last_insert_row_id)
        end
      end
      
      def count_rows(db, reader)
        return db.total_changes if db.total_changes
        count = 0
        reader.each { |row| count += 1 }
        count
      end
      
      def free_reader(reader)
        reader.close
      end
      
      def fetch_fields(reader)
        reader.columns.map { |field| Inflector.underscore(field).to_sym }
      end
    
      module Mappings
        class Table
          def to_exists_sql
            @to_exists_sql || @to_exists_sql = <<-EOS.compress_lines
              SELECT "name"
              FROM "sqlite_master"
              WHERE "type" = "table"
                AND "name" = #{@adapter.quote_value(name)}
            EOS
          end
        end # class Table
        
        class Column
          def serial_declaration
            "AUTOINCREMENT"
          end
          
          def size
            nil
          end
        end # class Column
      end # module Mappings
      
    end # class Sqlite3Adapter
    
  end # module Adapters
end # module DataMapper