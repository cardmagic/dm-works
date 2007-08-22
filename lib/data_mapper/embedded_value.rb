module DataMapper
  
  class EmbeddedValue
    
    def initialize(klass, &block)
      @klass = klass
      instance_eval(&block)
      
    end
    
    def property(name, type, options = {})
      database.schema[@klass].add_column(name, type, options)
    end
    
    class Proxy
      
      def initialize(instance)
        @instance = instance
      end
      
      def method_missing(sym, *args)
        if sym =~ /\=$/
          @instance.instance_variable_set("@#{sym}", *args)
        else
          @instance.instance_variable_get("@#{sym}")
        end
      end
      
    end
    
  end
  
end # module DataMapper