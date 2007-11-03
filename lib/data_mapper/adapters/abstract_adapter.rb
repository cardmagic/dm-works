module DataMapper
  module Adapters
      
    class AbstractAdapter
  
      # Instantiate an Adapter by passing it a DataMapper::Database
      # object for configuration.
      def initialize(configuration)
        @configuration = configuration
      end
      
      def index_path
        @configuration.index_path
      end
      
      def name
        @configuration.name
      end
      
      def delete(instance_or_klass, options = nil)
        raise NotImplementedError.new
      end
      
      def save(session, instance)
        raise NotImplementedError.new
      end
      
      def load(session, klass, options)
        raise NotImplementedError.new
      end
      
      def logger
        @logger || @logger = @configuration.logger
      end
      
    end # class AbstractAdapter
    
  end # module Adapters
end # module DataMapper