require 'data_mapper/adapters/data_object_adapter'
begin
  require 'do_postgres'
rescue LoadError
  STDERR.puts <<-EOS
You must install the DataObjects::PostgreSQL driver.
  rake dm:install:postgresql
EOS
  exit
end

module DataMapper
  module Adapters
    
    class PostgresqlAdapter < DataObjectAdapter
      
      def schema_search_path
        @schema_search_path || @schema_search_path = begin
          if @configuration.schema_search_path
            @configuration.schema_search_path.split(',').map do |part|
              part.blank? ? nil : part.strip.ensure_wrapped_with("'")
            end.compact
          else
            []
          end
        end
      end
      
      def create_connection
        conn = DataObject::Postgres::Connection.new("dbname=#{@configuration.database}")
        conn.logger = self.logger
        conn.open
        return conn
             
        unless schema_search_path.empty?
          execute("SET search_path TO #{schema_search_path}")
        end
        
        return connection
      end
      
      def database_column_name
        "TABLE_CATALOG"
      end
            
      TABLE_QUOTING_CHARACTER = '"'.freeze
      COLUMN_QUOTING_CHARACTER = '"'.freeze
      
      TYPES.merge!({
        :integer => 'integer'.freeze,
        :datetime => 'timestamp with time zone'.freeze
      })
        
      module Mappings
        class Table
          def sequence_sql
            @sequence_sql ||= quote_table("_id_seq").freeze
          end
          
          def to_create_table_sql
            schema_name = name.index('.') ? name.split('.').first : nil
            schema_list = @adapter.query('SELECT nspname FROM pg_namespace').join(',')
          
            sql = if schema_name and !schema_list.include?(schema_name)
                "CREATE SCHEMA #{@adapter.quote_table_name(schema_name)}; " 
            else
              ''
            end
            
            sql << "CREATE TABLE " << to_sql
          
            sql << " (" << columns.map do |column|
              column.to_long_form
            end.join(', ') << ")"
          
            return sql
          end
          
          # def to_exists_sql
          #   @to_exists_sql || @to_exists_sql = <<-EOS.compress_lines
          #     SELECT TABLE_NAME
          #     FROM INFORMATION_SCHEMA.TABLES
          #     WHERE TABLE_NAME = ?
          #       AND TABLE_CATALOG = ?
          #   EOS
          # end
          # 
          # def to_column_exists_sql
          #   @to_column_exists_sql || @to_column_exists_sql = <<-EOS.compress_lines
          #     SELECT TABLE_NAME, COLUMN_NAME
          #     FROM INFORMATION_SCHEMA.COLUMNS
          #     WHERE TABLE_NAME = ?
          #     AND COLUMN_NAME = ?
          #     AND TABLE_CATALOG = ?
          #   EOS
          # end          
                    
          private 
          
          def quote_table(table_suffix = nil)
            parts = name.split('.')
            parts.last << table_suffix if table_suffix
            parts.map { |part|
              @adapter.quote_table_name(part) }.join('.')
          end
        end # class Table
        
        class Schema
          
          def database_tables
            get_database_tables("public")
          end
          
        end
        
        class Column
          def serial_declaration
            "SERIAL"
          end
          
          def to_long_form
            @to_long_form || begin
              @to_long_form = "#{to_sql}"
              
              if serial? && !serial_declaration.blank?
                @to_long_form << " #{serial_declaration}"
              else
                @to_long_form << " #{type_declaration}"
                
                unless nullable? || not_null_declaration.blank?
                  @to_long_form << " #{not_null_declaration}"
                end
                
                if key? && !primary_key_declaration.blank?
                  @to_long_form << " #{primary_key_declaration}"
                end

                if default && !default_declaration.blank?
                  @to_long_form << " #{default_declaration}"
                end
              end
                      
              @to_long_form
            end
          end
          
          def size
            nil
          end
        end # class Column
      end # module Mappings
      
    end # class PostgresqlAdapter
    
  end # module Adapters
end # module DataMapper
