module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class TableExistsCommand
      
          def initialize(adapter, klass_or_name)
            @adapter, @klass_or_name = adapter, klass_or_name
            @table = @adapter.table(@klass_or_name)
          end
          
          def table_name
            @adapter.quote_value(@table.name)
          end
          
          def to_sql
            unless table_name.index(".")
              "select table_name from information_schema.tables where table_name = #{table_name} and table_catalog = '#{@adapter.schema.name}'"
            else
              table_schema, table_name = @table.name.split(".")
              "select table_name from information_schema.tables where table_name = '#{table_name}' and table_catalog = '#{table_schema}'"
            end
          end
          
          def call
            @adapter.execute(to_sql) { |reader, row_count| row_count > 0 }
          end          
      
        end
    
      end
    end
  end
end