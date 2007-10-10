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
          # This should be removable in favor of the new information_schema version
          def to_sql
            "SELECT name FROM sqlite_master WHERE type = \"table\" AND name = #{table_name}"
          end
          
          # This should be removable in favor of the new #call impl
          def call
            reader = @adapter.connection { |db| db.query(to_sql) }
            result = reader.entries.size > 0
            reader.close
            result
          end
        end # class TableExistsCommand
         
        class SaveCommand
          # The main difference here is the lack of the PRIMARY KEY command, which SQLite probably supports
          def to_create_table_sql
            sql = "CREATE TABLE " << @table.to_sql

            sql << " (" << @table.columns.map do |column|
              column_long_form(column)
            end.join(', ') << ")"

            return sql
          end
          
          # Can we just use the PG version as the default?
          def column_long_form(column)
            long_form = "#{column.to_sql} #{@adapter.class::TYPES[column.type] || column.type}"

            long_form << " NOT NULL" unless column.nullable?
            long_form << " PRIMARY KEY" if column.key?
            long_form << " default #{column.options[:default]}" if column.options.has_key?(:default)

            return long_form
          end
          
          # This should be replaced with a generic Adapter#insert command
          def execute_insert(sql)
            @adapter.insert(sql) { |insert_id| insert_id }
          end
          
          # We need to update count_rows to use total_changes if appropriate, but then this should swap
          # right out
          def execute_update(sql)
            @adapter.connection do |db|
              db.query(sql)
              db.total_changes > 0
            end
          end

        end # class SaveCommand
        
        class DeleteCommand
          # We need to replace this with drop/reload
          def to_truncate_sql
            "DELETE FROM " << @table.to_sql
          end
          
          # Delete#execute should work just fine
          def execute(sql)
            @adapter.connection do |db|
              db.query(sql)
              db.total_changes > 0
            end
          end
          
        end # class DeleteCommand
         
      end # module Commands
      
    end # class Sqlite3Adapter
    
  end # module Adapters
end # module DataMapper