require File.dirname(__FILE__) + '/table'
    
module DataMapper
  module Adapters
    module Sql
      module Mappings
    
        class Schema
    
          attr_reader :name
          
          def initialize(adapter, database_name)
            @name = database_name
            @adapter = adapter
            @tables = Hash.new { |h,k| h[k] = Table.new(@adapter, k) }
          end
          
          def [](klass)
            @tables[klass]
          end
      
          def each
            @tables.values.each do |table|
              yield table
            end
          end
    
        end
    
      end
    end
  end
end