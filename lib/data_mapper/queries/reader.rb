module DataMapper
  module Queries
  
    class Reader
      
      attr_reader :columns
      
      def initialize(database_result_set)
      end
      
      def eof?
        raise NotImplementedError.new
      end
      
      def records_affected
        raise NotImplementedError.new
      end
      
      def each
        raise NotImplementedError.new
      end
      
      def entries
        raise NotImplementedError.new
      end
      
      def [](column)
        raise NotImplementedError.new
      end
      
      def each_pair
        raise NotImplementedError.new
      end
      
      def close
        raise NotImplementedError.new
      end
      
    end
  
  end # module Queries
end # module DataMapper