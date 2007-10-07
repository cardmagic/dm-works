require 'data_mapper/adapters/sql_adapter'
require 'data_mapper/support/connection_pool'

begin
  require 'postgres'
rescue LoadError
  STDERR.puts <<-EOS.gsub(/^(\s+)/, '')
    This adapter currently depends on the \"postgres\" gem.
    If some kind soul would like to make it work with
    a pure-ruby version that'd be super spiffy.
  EOS
  
  raise
end

module DataMapper
  module Adapters
    module Sql
      module Mappings
        class Table

          def sequence_sql
            @sequence_sql ||= quote_table("_id_seq").freeze
          end
          
          private 
          
          def quote_table(table_suffix = nil)
            parts = name.split('.')
            parts.last << table_suffix if table_suffix
            parts.map { |part|
              @adapter.quote_table_name(part) }.join('.')
          end
        end
      end
    end
    
    class PostgresqlAdapter < SqlAdapter
      
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
      
      def type_cast_boolean(value)
        case value
          when TrueClass, FalseClass then value
          when "t", "true", "TRUE" then true
          when "f", nil then false
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
      
      TYPES.merge!({
        :integer => 'integer'.freeze,
        :string => 'varchar'.freeze,
        :text => 'text'.freeze,
        :class => 'varchar'.freeze,
        :datetime => 'timestamp with time zone'.freeze
      })

      module Commands
        
        class DeleteCommand
          
          # I don't know why the default one doesn't work
          def execute(sql)
            @adapter.execute(sql) do |reader, row_count|
              reader.status == PGresult::COMMAND_OK
            end
          end

          # this should be replaced with drop/rebuild
          def to_truncate_sql
            sequence = @table.sequence_sql
            # truncate the table and reset the sequence value
            sql = "DELETE FROM " << @table.to_sql
            if @table.key.auto_increment?
              sql << <<-EOS.compress_lines
                ; SELECT setval('#{sequence}',
                  (SELECT COALESCE( MAX(id) + (SELECT increment_by FROM #{sequence} ),
                  (SELECT min_value FROM #{sequence})
                ) FROM #{@table.to_sql}), false)
              EOS
            end
            return sql
          end

        end
        
        class SaveCommand
          
          # Fix this to use the RETURNING hack
          def execute_insert(sql)
            @adapter.connection do |db|
              @adapter.log.debug(sql)
              db.exec(sql)
              # Current id or latest value read from sequence in this session
              # See: http://www.postgresql.org/docs/8.1/interactive/functions-sequence.html
              @instance.key || db.exec("SELECT last_value from #{@table.sequence_sql}")[0][0]
            end
          end
          
          # This needs to be special-cased because of the possibility of creating a new schema... still it should be refactored
          def to_create_table_sql
            schema_name = @table.name.index('.') ? @table.name.split('.').first : nil
            schema_list = @adapter.connection { |db| db.exec('SELECT nspname FROM pg_namespace').result.collect { |r| r[0] }.join(',') }
          
            sql = if schema_name and !schema_list.include?(schema_name)
                "CREATE SCHEMA #{@adapter.quote_table_name(schema_name)}; " 
            else
              ''
            end
            
            sql << "CREATE TABLE " << @table.to_sql
          
            sql << " (" << @table.columns.map do |column|
              column_long_form(column)
            end.join(', ') << ")"
          
            return sql
          end

          # could we just make this the default?
          def column_long_form(column)
            
            long_form = if column.key? 
              "#{column.to_sql} serial primary key"
            else
              "#{column.to_sql} #{@adapter.class::TYPES[column.type] || column.type}"
            end  
            long_form << " NOT NULL" unless column.nullable?
            long_form << " default #{column.options[:default]}" if column.options.has_key?(:default)

            return long_form
          end
        end
        
      end
      
    end # class PostgresqlAdapter
    
  end # module Adapters
end # module DataMapper
