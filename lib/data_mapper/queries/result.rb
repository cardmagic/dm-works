module DataMapper
  module Queries
  
    class Result
      
      attr_accessor :size, :last_inserted_id
      
      def initialize(size, last_inserted_id = nil)
        @size, @last_inserted_id = size, last_inserted_id
      end
      
      def success?
        size > 0
      end
      
    end # class Result
  
  end # module Queries
end # module DataMapper