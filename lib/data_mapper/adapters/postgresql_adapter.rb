require 'data_mapper/adapters/data_object_adapter'

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
        connection = PGconn.connect(
          @configuration.host,
          5432,
          "",
          "",
          @configuration.database,
          @configuration.username,
          @configuration.password
        )
     
        unless schema_search_path.empty?
          connection.exec("SET search_path TO #{schema_search_path}")
        end
        
        return connection
      end

      def close_connection(conn)
        conn.close
      end

      def query_returning_reader(db, sql)
        db.exec(sql)
      end
      
      def count_rows(db, reader)
        return reader.entries.size if reader.entries.is_a?(Array) && reader.entries.size != 0
        reader.cmdstatus.split(' ').last.to_i            
      end
      
      def free_reader(reader)
        reader.clear
      end
      
      def fetch_fields(reader)
        reader.fields.map { |field| Inflector.underscore(field).to_sym }
      end
            
      TABLE_QUOTING_CHARACTER = '"'.freeze
      COLUMN_QUOTING_CHARACTER = '"'.freeze
      
      TYPES.merge!({
        :integer => 'integer'.freeze,
        :datetime => 'timestamp with time zone'.freeze
      })
      
      def insert(*args)
        connection do |db|
          sql = escape_sql(*args)
          log.debug { sql }
          db.exec(sql)
          # Current id or latest value read from sequence in this session
          # See: http://www.postgresql.org/docs/8.1/interactive/functions-sequence.html
          db.exec("SELECT last_value from #{@table.sequence_sql}")[0][0]
        end
      end
        
      module Mappings
        class Table
          def sequence_sql
            @sequence_sql ||= quote_table("_id_seq").freeze
          end
          
          def to_create_table_sql
            schema_name = name.index('.') ? name.split('.').first : nil
            schema_list = @adapter.connection { |db| db.exec('SELECT nspname FROM pg_namespace').result.collect { |r| r[0] }.join(',') }
          
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
          
          private 
          
          def quote_table(table_suffix = nil)
            parts = name.split('.')
            parts.last << table_suffix if table_suffix
            parts.map { |part|
              @adapter.quote_table_name(part) }.join('.')
          end
        end # class Table
        
        class Column
          def serial_declaration
            "SERIAL"
          end
          
          def size
            nil
          end
        end # class Column
      end # module Mappings
      
    end # class PostgresqlAdapter
    
  end # module Adapters
end # module DataMapper
