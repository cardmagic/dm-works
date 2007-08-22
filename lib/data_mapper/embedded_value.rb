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
    
    def self.define(container, class_or_name, &block)
       embedded_class, embedded_class_name, accessor_name = nil

      if class_or_name.kind_of?(Class)
        embedded_class = class_or_name
        embedded_class_name = class_or_name.name.split('::').last
        accessor_name = Inflector.underscore(embedded_class_name)
      else
        accessor_name = class_or_name.to_s
        embedded_class_name = Inflector.camelize(accessor_name)
        embedded_class = Class.new(EmbeddedValue)
        container.const_set(embedded_class_name, embedded_class) unless container.const_defined?(embedded_class_name)
      end

      embedded_class.instance_variable_set('@containing_class', container)
      embedded_class.class_eval(&block) if block_given?

      container.class_eval <<-EOS
        def #{accessor_name}
          #{embedded_class_name}.new(self)
        end
      EOS
    end
    
  end
  
end # module DataMapper