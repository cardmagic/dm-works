require 'data_mapper/adapters/data_object_adapter'
require 'do_sqlite3'

module DataMapper
  module Adapters
    
    class Sqlite3Adapter < DataObjectAdapter
      
      TYPES.merge!({
        :integer => 'INTEGER'.freeze,
        :string => 'TEXT'.freeze,
        :text => 'TEXT'.freeze,
        :class => 'TEXT'.freeze
      })

      TABLE_QUOTING_CHARACTER = '"'.freeze
      COLUMN_QUOTING_CHARACTER = '"'.freeze
      
      def create_connection
        conn = DataObject::Sqlite3::Connection.new("dbname=#{@configuration.database}")
        conn.open
        return conn
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