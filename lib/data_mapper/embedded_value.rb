module DataMapper
  
  class EmbeddedValue
    EMBEDDED_PROPERTIES = []
    
    def initialize(instance)
      @instance = instance
      @container_prefix = ''

      # force lazy load on access to any lazy-loaded embed property
      @instance.lazy_load!(*self.class::EMBEDDED_PROPERTIES) if lazy?
    end

    def self.inherited(base)
      base.const_set('EMBEDDED_PROPERTIES', [])
    end
    
    # add an embedded property
    def self.property(name, type, options = {})
      # set lazy option on the mapping if defined in the embed block
      options[:lazy] ||= @container_lazy
      mapping = database.schema[containing_class].add_column("#{@container_prefix}#{name}", type, options)

      self::EMBEDDED_PROPERTIES << "#{@container_prefix}#{name}"
      define_property_getter(name, mapping)
      define_property_setter(name, mapping)
    end
    
    # define embedded property getters
    def self.define_property_getter(name, mapping)
      # add convenience method on non-embedded base for #update_attributes
      self.containing_class.property_getter(mapping)

      # add the method on the embedded class
      class_eval <<-EOS
        def #{name}
          @instance.instance_variable_get(#{mapping.instance_variable_name.inspect})
        end
      EOS

      # add a shortcut boolean? method if applicable (ex: activated?)
      if mapping.type == :boolean
        class_eval("alias #{name}? #{name}")
      end
    end
    
    # define embedded property setters
    def self.define_property_setter(name, mapping)
      # add convenience method on non-embedded base for #update_attributes
      self.containing_class.property_setter(mapping)

      # add the method on the embedded class
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
    
    def self.define(container, class_or_name, options, &block)
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

      if options[:prefix]
        container_prefix = options[:prefix].kind_of?(String) ? options[:prefix] : "#{accessor_name}_"
        embedded_class.instance_variable_set('@container_prefix', container_prefix)
      end

      embedded_class.instance_variable_set('@containing_class', container)
      embedded_class.instance_variable_set('@container_lazy', !!options[:lazy])
      embedded_class.class_eval("def lazy?; #{!!options[:lazy]} end")
      embedded_class.class_eval(&block) if block_given?

      container.class_eval <<-EOS
        def #{accessor_name}
          #{embedded_class_name}.new(self)
        end
      EOS
    end
    
  end
  
end # module DataMapper
