require 'data_mapper/adapters/abstract_adapter'
require 'data_mapper/support/connection_pool'

begin
  require 'mysql'
rescue LoadError
  STDERR.puts <<-EOS.gsub(/^(\s+)/, '')
    This adapter currently depends on the \"mysql\" gem.
    If some kind soul would like to make it work with
    a pure-ruby version that'd be super spiffy.
  EOS
  
  raise
end

module DataMapper
  module Adapters
    
    class MysqlAdapter < AbstractAdapter
      
      def initialize(configuration)
        super
        @connections = Support::ConnectionPool.new { Queries::Connection.new(@configuration)  }
      end
      
      def connection
        raise ArgumentError.new('MysqlAdapter#connection requires a block-parameter') unless block_given?
        begin
          @connections.hold { |connection| yield connection }
        rescue Mysql::Error => me
          
          @configuration.log.fatal(me)
          
          @connections.available_connections.each do |sock|
            begin
              sock.close
            rescue => se
              @configuration.log.error(se)
            end
          end
          
          @connections.available_connections.clear
          raise me
        end
      end
      
      module Quoting

        def quote_table_name(name)
          name.ensure_wrapped_with('`')
        end

        def quote_column_name(name)
          name.ensure_wrapped_with('`')
        end

      end # module Quoting

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
            @dbh = Mysql.new(database.host, database.username, database.password, database.database)
            database.log.debug("Initializing Connection for Database[#{database.name}]")
            super(database.log)
          end
          
          def execute(statement)
            send_query(statement)
            Result.new(@dbh.affected_rows, @dbh.insert_id)
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
            results.fetch_fields.each_with_index do |field, index|
              @columns[field.name] = index
            end
            @current_row_index = 0
          end
          
          def eof?
            records_affected <= @current_row_index
          end
          
          def records_affected
            @results.num_rows
          end
          
          def next
            @current_row_index += 1
            @current_row = @results.fetch_row
            self
          end
      
          def each
            @results.each do |row|
              @current_row = row
              yield self
            end
          end
      
          def [](column)
            index = @columns[column]
            return nil if index.nil?
            @current_row[index]
          end
          
          def each_pair
            @columns.each_pair do |column_name, index|
              yield(column_name, @current_row[index])
            end
          end
          
          def close
            @results.free
          end
      
        end # class Reader
        
      end # module Queries
        
    end # class MysqlAdapter
    
  end # module Adapters
end # module DataMapper