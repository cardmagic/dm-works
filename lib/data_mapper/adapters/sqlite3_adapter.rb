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
      
      def create_connection
        conn = SQLite3::Database.new(@configuration.database)
        conn.results_as_hash = true
        conn
      end
      
      def close_connection(conn)
        conn.close
      end
      
      def execute(*args)
        connection do |db|
          sql = escape_sql(*args)
          log.debug(sql)
          reader = db.query(sql)
          result = yield(reader, reader.count)
          reader.close
          result
        end
      end
      
      def query(*args)
        reader = connection { |db| db.query(escape_sql(*args)) }
        
        fields = nil
        rows = []
        
        until reader.eof?
          hash = reader.next
          break if hash.nil?
          
          fields = hash.keys.select { |field| field.is_a?(String) } unless fields
          
          rows << fields.map { |field| hash[field] }
        end
        
        struct = Struct.new(*fields)
        
        rows.map do |row|
          struct.new(*row)
        end
      end
      
      TYPES.merge!({
        :integer => 'INTEGER'.freeze,
        :string => 'TEXT'.freeze,
        :text => 'TEXT'.freeze,
        :class => 'TEXT'.freeze
      })

      TABLE_QUOTING_CHARACTER = '"'.freeze
      COLUMN_QUOTING_CHARACTER = '"'.freeze
      
      def type_cast_boolean(value)
        case value
          when TrueClass, FalseClass then value
          when "1", "true", "TRUE" then true
          when "0", nil then false
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
    
      module Commands
        
        class TableExistsCommand
          def to_sql
            "SELECT name FROM sqlite_master WHERE type = \"table\" AND name = #{table_name}"
          end
          
          def call
            reader = @adapter.connection { |db| db.query(to_sql) }
            result = reader.entries.size > 0
            reader.close
            result
          end
        end # class TableExistsCommand
         
        class SaveCommand
          def to_create_table_sql
            table = @adapter[@instance]

            sql = "CREATE TABLE " << table.to_sql

            sql << " (" << table.columns.map do |column|
              column_long_form(column)
            end.join(', ') << ")"

            return sql
          end

          def column_long_form(column)
            long_form = "#{column.to_sql} #{@adapter.class::TYPES[column.type] || column.type}"

            long_form << " NOT NULL" unless column.nullable?
            long_form << " PRIMARY KEY" if column.key?
            long_form << " default #{column.options[:default]}" if column.options.has_key?(:default)

            return long_form
          end
          
          def execute_insert(sql)
            @adapter.connection do |db|
              db.query(sql)
              db.last_insert_row_id
            end
          end
          
          def execute_update(sql)
            @adapter.connection do |db|
              db.query(sql)
              db.total_changes > 0
            end
          end
          
          def execute_create_table(sql)
            @adapter.connection { |db| db.query(sql) }
            true
          end
        end # class SaveCommand
        
        class DeleteCommand
          def to_truncate_sql
            "DELETE FROM " << @adapter[@klass_or_instance].to_sql
          end
          
          def execute(sql)
            @adapter.connection do |db|
              db.query(sql)
              db.total_changes > 0
            end
          end
          
          def execute_drop(sql)
            @adapter.connection { |db| db.query(sql) }
            true
          end
        end # class DeleteCommand
         
      end # module Commands
      
    end # class Sqlite3Adapter
    
  end # module Adapters
end # module DataMapper