module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class AdvancedConditions
      
          def initialize(adapter, loader, explicit_conditions, implicit_conditions)
            @adapter, @loader = adapter, loader
            @conditions = parse_conditions(conditions)
            @conditions += implicit_conditions
          end
      
          def empty?
            conditions.empty?
          end
          
          def implicits
            []
          end
      
          def to_sql
            ""
          end
          
          private
            
            def implicit_conditions
              @options.partition { |k,v| }
            end
            
            def parse_conditions(conditions, options)
              conditions = case conditions
              when NilClass then []
              when Array then conditions
              when Hash then [conditions]
              else raise "Unable to parse conditions: #{conditions.inspect}"
              end
            end
                    
        end
    
      end
    end
  end
end