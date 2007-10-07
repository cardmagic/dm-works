module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class CountCommand
      
          def initialize(adapter, klass_or_instance, options = nil)
            @adapter, @klass_or_instance, @options = adapter, klass_or_instance, options
            @table = adapter.table(@klass_or_instance)
          end
          
          def to_sql
            "SELECT COUNT(*) AS row_count FROM " << @table.to_sql
          end
          
          def call
            @adapter.query(to_sql).first.row_count.to_i
          end
          
        end
    
      end
    end
  end
end