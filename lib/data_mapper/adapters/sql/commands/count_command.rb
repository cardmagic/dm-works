module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class CountCommand
      
          def initialize(adapter, klass_or_instance, options = nil)
            @adapter, @klass_or_instance, @options = adapter, klass_or_instance, options
          end
          
          def table
            case @klass_or_instance
            when Class, String then @adapter[@klass_or_instance]
            when DataMapper::Adapters::Sql::Mappings::Table then @klass_or_instance
            else raise "Unsupported type: #{@klass_or_instance.inspect}"
            end
          end
          
          def to_sql
            "SELECT COUNT(*) AS row_count FROM " << table.to_sql
          end
          
          def call
            @adapter.query(to_sql).first.row_count
          end
          
        end
    
      end
    end
  end
end