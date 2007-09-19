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
    
    class PostgresqlAdapter < SqlAdapter

      def create_connection
        PGconn.connect(
          @configuration.host,
          5432,
          "",
          "",
          @configuration.database,
          @configuration.username,
          @configuration.password
        )
      end
      
      def close_connection(conn)
        conn.close
      end
      
      def execute(*args)
        connection do |db|
          sql = escape_sql(*args)
          log.debug(sql)
          pg_result = db.exec(sql)
          result = yield(pg_result, pg_result.cmdstatus.split(' ').last.to_i)
          pg_result.clear
          result
        end
      end
      
      def query(*args)
        execute(*args) do |reader,num_rows|
          struct = Struct.new(*reader.fields.map { |field| Inflector.underscore(field.name).to_sym })
          
          results = []
          
          reader.each do |row|
            results << struct.new(*row)
          end
          
          results
        end
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
      
      def sequence_name(table)
        quote_table_name(table.to_sql.gsub('"', '') + "_id_seq")
      end
      
      TYPES.merge!({
        :integer => 'integer'.freeze,
        :string => 'varchar'.freeze,
        :text => 'text'.freeze,
        :class => 'varchar'.freeze,
        :datetime => 'timestamp with time zone'.freeze
      })

      module Commands
        
        class TableExistsCommand
          def to_sql
            # TODO cache this somewhere
            schema_list = @adapter.connection { |db| db.exec('SHOW search_path').result[0][0].split(',').collect { |s| "'#{s}'" }.join(',') }
            "SELECT tablename FROM pg_tables WHERE schemaname IN (#{schema_list}) AND tablename = #{table_name}"
          end
          
          def call
            sql = to_sql
            @adapter.log.debug(sql)
            reader = @adapter.connection { |db| db.exec(sql) }
            result = reader.entries.size > 0
            reader.clear
            result
          end
        end
        
        class DeleteCommand
          
          def execute(sql)
            @adapter.connection do |db|
              @adapter.log.debug(sql)
              db.exec(sql).status == PGresult::COMMAND_OK
            end
          end

          def to_truncate_sql
            table = @adapter[@klass_or_instance]
            sequence = @adapter.sequence_name(table)
            # truncate the table and reset the sequence value
            "DELETE FROM " << table.to_sql << "; SELECT setval('#{sequence}', (SELECT COALESCE(MAX(id)+(SELECT increment_by FROM #{sequence}), (SELECT min_value FROM #{sequence})) FROM #{table.to_sql}), false)"
          end

          def execute_drop(sql)
            @adapter.log.debug(sql)
            @adapter.connection { |db| db.exec(sql) }
            true
          end
          
        end
        
        class SaveCommand
          
          def execute_insert(sql)
            @adapter.connection do |db|
              @adapter.log.debug(sql)
              db.exec(sql)
              # Current id or latest value read from sequence in this session
              # See: http://www.postgresql.org/docs/8.1/interactive/functions-sequence.html
              @instance.key || db.exec("SELECT last_value from #{@adapter.sequence_name(@adapter[@instance.class])}")[0][0]
            end
          end
          
          def execute_update(sql)
            @adapter.connection do |db|
              @adapter.log.debug(sql)
              db.exec(sql).cmdstatus.split(' ').last.to_i > 0
            end
          end
          
          def execute_create_table(sql)
            @adapter.log.debug(sql)
            @adapter.connection { |db| db.exec(sql) }
            true
          end
          
          def to_create_table_sql
            table = @adapter[@instance]

            sql = "CREATE TABLE " << table.to_sql

            sql << " (" << table.columns.map do |column|
              column_long_form(column)
            end.join(', ') << ")"

            return sql
          end

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
               #  
               # class LoadCommand
               #   def eof?(pg_result)
               #     pg_result.result.entries.empty?
               #   end
               #   
               #   def close_reader(pg_result)
               #     pg_result.clear
               #   end
               #   
               #   def execute(sql)
               #     @adapter.log.debug(sql)
               #     @adapter.connection { |db| db.exec(to_sql) }
               #   end
               #   
               #   def fetch_one(pg_result)
               #     load(process_row(columns(pg_result), pg_result.result[0]))
               #   end
               #   
               #   def fetch_all(pg_result)
               #     load_instances(pg_result.fields, pg_result)
               #   end
               # 
               #   private
               #   
               #   def columns(pg_result)
               #     columns = {}
               #     pg_result.fields.each_with_index do |name, index|
               #       columns[name] = index
               #     end
               #     columns
               #   end
               #  
               #   def process_row(columns, row)
               #     hash = {}
               #     columns.each_pair do |name,index|
               #       hash[name] = row[index]
               #     end
               #     hash
               #   end
               #   
               # end
        
      end
      
    end # class PostgresqlAdapter
    
  end # module Adapters
end # module DataMapper