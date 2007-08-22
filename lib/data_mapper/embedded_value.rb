module DataMapper
  
  class EmbeddedValue
    
    def initialize(instance)
      @instance = instance
    end
    
    def self.property(name, type, options = {})
      mapping = database.schema[containing_class].add_column(name, type, options)
      define_property_getter(name, mapping)
      define_property_setter(name, mapping)
    end
    
    def self.define_property_getter(name, mapping)
      class_eval <<-EOS
        def #{name}
          @instance.instance_variable_get(#{mapping.instance_variable_name.inspect})
        end
      EOS
    end
    
    def self.define_property_setter(name, mapping)
      class_eval <<-EOS
        def #{name.to_s.sub(/\?$/, '')}=(value)
          @instance.instance_variable_set(#{mapping.instance_variable_name.inspect}, value)
        end
      EOS
    end
    
    def self.containing_class
      @containing_class || @containing_class = begin
        tree = name.split('::')
        tree.pop
        tree.inject(Object) { |klass, current| klass.const_get(current) }
      end
    end
    
  end
  
end # module DataMapper