module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class TableExistsCommand
      
          def initialize(adapter, klass_or_name)
            @adapter, @klass_or_name = adapter, klass_or_name
            @table = @adapter.table(@klass_or_name)
          end

          def to_sql
            "SHOW TABLES LIKE #{@adapter.quote_value(@table.name)}"
          end
          
          def call
            @adapter.execute(to_sql) do |reader, row_count|
              row_count > 0
            end
          end
      
        end
    
      end
    end
  end
end