module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class AdvancedConditions
      
          def initialize(adapter, loader, conditions)
            @adapter, @loader, @conditions = adapter, loader, conditions
            @has_id = false
          end
      
          def empty?
            @conditions.nil? && implicits.empty? 
          end
          
          def implicits
            []
          end
      
          def sql
            ""
          end
        end
    
      end
    end
  end
end