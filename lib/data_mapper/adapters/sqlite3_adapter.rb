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
      
      def batch_insertable?
        false
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
          
          def unquote_default(default)
            default.gsub(/(^'|'$)/, "") rescue default
          end
          
        end # class Table
        
        class Column
          def serial_declaration
            "AUTOINCREMENT"
          end
          
          def size
            nil
          end
          
          def to_backup_and_recreate_sql
            backup_table = @adapter.table("#{@table.name}_backup")
            
            @table.columns.each do |column|
              backup_table.add_column(column.name, column.type, column.options)
            end
            
            backup_table.temporary = true
            
            <<-EOS.compress_lines
              BEGIN TRANSACTION;
              #{backup_table.to_create_sql};
              INSERT INTO #{backup_table.to_sql} SELECT #{@table.columns.map { |c| c.to_sql }.join(', ')} FROM #{@table.to_sql};
              DROP TABLE #{@table.to_sql};
              #{@table.to_create_sql};
              INSERT INTO #{@table.to_sql} SELECT #{backup_table.columns.map { |c| c.to_sql }.join(', ')} FROM #{backup_table.to_sql};
              DROP TABLE #{backup_table.to_sql};
              COMMIT;
            EOS
          end
          
          alias to_drop_sql to_backup_and_recreate_sql
          alias to_alter_sql to_backup_and_recreate_sql
                    
          def backup_and_recreate!
            @adapter.connection do |db|
              to_backup_and_recreate_sql.split(';').each do |sql|
                command = db.create_command(sql)
                command.execute_non_query
              end
            end
          end
          
          alias alter! backup_and_recreate!
          
          def drop!
            @table.columns.delete(self)
            backup_and_recreate!
          end
          
          
        end # class Column
      end # module Mappings
      
    end # class Sqlite3Adapter
    
  end # module Adapters
end # module DataMapper