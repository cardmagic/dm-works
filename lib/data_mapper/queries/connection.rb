require File.dirname(__FILE__) + '/result'
require File.dirname(__FILE__) + '/reader'

module DataMapper
  module Queries
  
    class Connection
      
      def initialize(logger)
        @logger = logger
      end
      
      def log
        @logger
      end
      
      def execute(sql)
        raise NotImplementedError.new
        Results.new
      end
      
      def query(sql)
        raise NotImplementedError.new
        Reader.new
      end
      
      def close
        raise NotImplementedError.new
      end
      
    end
  
  end # module Queries
end # module DataMapper