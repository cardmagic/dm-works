require 'data_mapper/adapters/abstract_adapter'
require 'data_mapper/support/connection_pool'

require 'sqlite3'

module DataMapper
  module Adapters
    
    class Sqlite3Adapter < AbstractAdapter
      
      def initialize(configuration)
        super
        @connections = Support::ConnectionPool.new { Queries::Connection.new(@configuration)  }
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
      
      module Coersion

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

      end # module Coersion
      
      module Queries
        
        class Connection
      
          def initialize(database)
            @database = database
            @dbh = SQLite3::Database.new(database.database)
            database.log.debug("Initializing Connection for Database[#{database.name}]")
            super(database.log)
          end
          
          def execute(statement)
            send_query(statement)
            Result.new(@dbh.total_changes, @dbh.last_insert_row_id)
          end
      
          def query(statement)
            Reader.new(send_query(statement))
          end
      
          def close
            @dbh.close
          end
          
          private
          def send_query(statement)
            sql = statement.respond_to?(:to_sql) ? statement.to_sql : statement
            log.debug("Database[#{@database.name}] => #{sql}")
            @dbh.query(sql)
          end
          
        end # class Connection
        
        class Reader
      
          include Enumerable
          
          def initialize(results)
            @results = results
            @columns = {}
            @results.columns.each_with_index do |name, index|
              @columns[name] = index
            end
          end
          
          def eof?
            @results.eof?
          end
          
          def records_affected
            @results.entries.size
          end
          
          def next
            @current_row = @results.next
            self
          end
      
          def each
            until self.next.eof?
              yield(self)
            end
          end
      
          def [](column)
            index = @columns[column]
            return nil if index.nil? || @current_row.nil?
            @current_row[index]
          end
          
          def each_pair            
            @columns.each_pair do |column_name, index|
              yield(column_name, @current_row.nil? ? nil : @current_row[index])
            end
          end
          
          def close
            @results.close
          end
      
        end # class Reader
        
        class TableExistsStatement
          def to_sql
            "SELECT name FROM sqlite_master WHERE type = \"table\" AND name = #{@database.quote_value(@database[@klass].name)}"
          end
        end # class TableExistsStatement
         
        class CreateTableStatement
          def to_sql
            table = @database[@klass]

            sql = "CREATE TABLE " << table.to_sql

            sql << " (" << table.columns.map do |column|
              column_long_form(column)
            end.join(', ') << ")"

            return sql
          end

          def column_long_form(column)
            long_form = "#{column.to_sql} #{@database.adapter.class::TYPES[column.type] || column.type}"

            long_form << " NOT NULL" unless column.nullable?
            long_form << " PRIMARY KEY" if column.key?
            long_form << " default #{column.options[:default]}" if column.options.has_key?(:default)

            return long_form
          end
        end # class CreateTableStatement
        
        class TruncateTableStatement
          def to_sql
            "DELETE FROM " << @database[@klass].to_sql
          end
        end # class TruncateTableStatement
        
      end # module Queries
        
    end # class Sqlite3Adapter
    
  end # module Adapters
end # module DataMapper