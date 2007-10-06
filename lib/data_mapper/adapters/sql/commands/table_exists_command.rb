module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class TableExistsCommand
      
          def initialize(adapter, klass_or_name)
            @adapter, @klass_or_name = adapter, klass_or_name
          end
      
          def table_name
            @table_name || @table_name = case @klass_or_name
            when Mappings::Table then @adapter.quote_value(@klass_or_name.name)
            when String then @adapter.quote_value(@klass_or_name)
            when Class then @adapter.quote_value(@adapter[@klass_or_name].name)
            else raise ArgumentError.new('klass_or_name must be a mapped-class or a table name')
            end
          end
          
          def to_sql
            "SHOW TABLES LIKE #{table_name}"
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