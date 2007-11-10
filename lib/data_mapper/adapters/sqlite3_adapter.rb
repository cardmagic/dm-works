require 'data_mapper/adapters/data_object_adapter'
begin
  require 'do_sqlite3'
rescue LoadError
  STDERR.puts <<-EOS
You must install the DataObjects::SQLite3 driver.
  rake dm:install:sqlite3
EOS
  exit
end

module DataMapper
  module Adapters
    
    class Sqlite3Adapter < DataObjectAdapter
      
      TYPES.merge!({
        :integer => 'INTEGER'.freeze,
        :string => 'TEXT'.freeze,
        :text => 'TEXT'.freeze,
        :class => 'TEXT'.freeze,
        :boolean => 'INTEGER'.freeze
      })

      TABLE_QUOTING_CHARACTER = '"'.freeze
      COLUMN_QUOTING_CHARACTER = '"'.freeze
      
      def create_connection
        conn = DataObject::Sqlite3::Connection.new("dbname=#{@configuration.database}")
        conn.logger = self.logger
        conn.open
        return conn
      end
      
      def truncate(session, name)
        result = execute("DELETE FROM #{table(name).to_sql}")
        session.identity_map.clear!(name)
        result.to_i > 0
      end
                
      module Mappings
        
        class Schema
          def to_tables_sql
            @to_tables_sql || @to_tables_sql = <<-EOS.compress_lines
              SELECT "name" 
              FROM sqlite_master 
              where "type"= "table"
              and "name" <> "sqlite_sequence"
            EOS
          end
          alias_method :database_tables, :get_database_tables
        end # class Schema
        
        class Table
          def to_exists_sql
            @to_exists_sql || @to_exists_sql = <<-EOS.compress_lines
              SELECT "name"
              FROM "sqlite_master"
              WHERE "type" = "table"
                AND "name" = ?
            EOS
          end
          
          def to_column_exists_sql
            @to_column_exists_sql || @to_column_exists_sql = <<-EOS.compress_lines
              PRAGMA TABLE_INFO(?)
            EOS
          end
          alias_method :to_columns_sql, :to_column_exists_sql
          def get_database_columns
            columns = []            
            @adapter.connection do |db|
              command = db.create_command(to_columns_sql)
              command.execute_reader(name) do |reader|
                columns = reader.map {
                  @adapter.class::Mappings::Column.new(@adapter, name, reader.item(1), DataMapper::Adapters::Sqlite3Adapter::TYPES.index(reader.item(2)),reader.item(0).to_i)
                }
              end
            end
            columns
          end
          alias_method :database_columns, :get_database_columns
          
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