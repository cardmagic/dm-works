require 'data_mapper/adapters/sql_adapter'
require 'data_mapper/support/connection_pool'

require 'sqlite3'

module DataMapper
  module Adapters
    
    class Sqlite3Adapter < SqlAdapter
      
      def initialize(configuration)
        super
        @connections = Support::ConnectionPool.new do
          dbh = SQLite3::Database.new(configuration.database)
          dbh.results_as_hash = true
          dbh
        end
      end
      
      def connection
        raise ArgumentError.new('Sqlite3Adapter#connection requires a block-parameter') unless block_given?
        begin
          @connections.hold { |connection| yield connection }
        rescue SQLite3::Exception => sle
          
          @configuration.log.fatal(sle)
          
          @connections.available_connections.each do |sock|
            begin
              sock.close
            rescue => se
              @configuration.log.error(se)
            end
          end
          
          @connections.available_connections.clear
          raise sle
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
         
        class LoadCommand
          def eof?(reader)
            reader.eof?
          end
          
          def close_reader(reader)
            reader.close
          end
          
          def execute(sql)
            @adapter.connection { |db| db.query(to_sql) }
          end
          
          def fetch_one(reader)
            load(reader.next)
          end
          
          def fetch_all(reader)
            results = []
            set = []
            until reader.eof?
              hash = reader.next
              break if hash.nil?
              results << load(hash, set)
            end
            results
          end
          
          def load_structs(reader)
            struct = nil
            columns = nil
            results = []
            
            until reader.eof?
              hash = reader.next
              break if hash.nil?

              if struct.nil?
                columns = hash.keys.select { |c| c.is_a?(String) }
                struct = Struct.new(*columns.map { |c| c.to_sym })
              end
              
              results << struct.new(*columns.map { |c| hash[c] })
            end
            
            reader.close
            results
          end
        end
        
      end # module Commands
        
    end # class Sqlite3Adapter
    
  end # module Adapters
end # module DataMapper