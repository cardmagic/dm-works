module DataMapper
  
  class EmbeddedValue
    EMBEDDED_PROPERTIES = []
    
    def initialize(instance)
      @instance = instance
      @container_prefix = ''
    end

    def self.inherited(base)
      base.const_set('EMBEDDED_PROPERTIES', [])
    end
    
    # add an embedded property
    def self.property(name, type, options = {})
      # set lazy option on the mapping if defined in the embed block
      options[:lazy] ||= @container_lazy
      
      options[:reader] ||= options[:accessor] || @container_reader_visibility
      options[:writer] ||= options[:accessor] || @container_writer_visibility
      
      property_name = @container_prefix ? @container_prefix + name.to_s : name
      
      property = containing_class.property(property_name, type, options)
      define_property_getter(name, property)
      define_property_setter(name, property)
    end
    
    # define embedded property getters
    def self.define_property_getter(name, property)

      # add the method on the embedded class
      class_eval <<-EOS
        #{property.reader_visibility.to_s}
        def #{name}
          #{"@instance.lazy_load!("+ property.name.inspect + ")" if property.lazy?}
          @instance.instance_variable_get(#{property.instance_variable_name.inspect})
        end
      EOS

      # add a shortcut boolean? method if applicable (ex: activated?)
      if property.type == :boolean
        class_eval("alias #{property.name}? #{property.name}")
      end
    end
    
    # define embedded property setters
    def self.define_property_setter(name, property)

      # add the method on the embedded class
      class_eval <<-EOS
        #{property.writer_visibility.to_s}
        def #{name.to_s.sub(/\?$/, '')}=(value)
          @instance.instance_variable_set(#{property.instance_variable_name.inspect}, value)
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
    
    def self.define(container, name, options, &block)
      embedded_class, embedded_class_name, accessor_name = nil

      accessor_name = name.to_s
      embedded_class_name = Inflector.camelize(accessor_name)
      embedded_class = Class.new(EmbeddedValue)
      container.const_set(embedded_class_name, embedded_class) unless container.const_defined?(embedded_class_name)

      if options[:prefix]
        container_prefix = options[:prefix].kind_of?(String) ? options[:prefix] : "#{accessor_name}_"
        embedded_class.instance_variable_set('@container_prefix', container_prefix)
      end

      embedded_class.instance_variable_set('@containing_class', container)

      embedded_class.instance_variable_set('@container_lazy', !!options[:lazy])
      embedded_class.instance_variable_set('@container_reader_visibility', options[:reader] || options[:accessor] || :public)
      embedded_class.instance_variable_set('@container_writer_visibility', options[:writer] || options[:accessor] || :public)

      embedded_class.class_eval(&block) if block_given?

      container.class_eval <<-EOS
        def #{accessor_name}
          #{embedded_class_name}.new(self)
        end
      EOS
    end
    
  end
  
end # module DataMapper
