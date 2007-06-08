require 'data_mapper/mappings/table'
    
module DataMapper
  module Mappings
    
    class Schema
    
      def initialize(database)
        @database = database
        @tables = Hash.new { |h,k| h[k] = Table.new(@database, k) }
      end
    
      def [](klass)
        @tables[klass]
      rescue
        raise "#{klass.inspect} can't be mapped to a table"
      end
      
      def each
        @tables.values.each do |table|
          yield table
        end
      end
    
    end
    
  end
end