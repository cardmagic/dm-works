module DataMapper
  class Property
    
    # NOTE: check is only for psql, so maybe the postgres adapter should define
    # its own property options. currently it will produce a warning tho since
    # PROPERTY_OPTIONS is a constant
    PROPERTY_OPTIONS = [
      :public, :protected, :private, :accessor, :reader, :writer,
      :lazy, :default, :nullable, :key, :serial, :column, :size, :length,
      :format, :index, :check, :ordinal
    ]
    
    VISIBILITY_OPTIONS = [:public, :protected, :private]
    
    def initialize(klass, name, type, options)
      
      @klass, @name, @type, @options = klass, name, type, options
      @symbolized_name = name.to_s.sub(/\?$/, '').to_sym
      
      validate_options!
      determine_visibility!
      
      database.schema[klass].add_column(@symbolized_name, @type, @options)
      klass::ATTRIBUTES << @symbolized_name
      
      create_getter!
      create_setter!
      auto_validations!
      
    end
    
    def validate_options!
      @options.each_pair do |k,v|
        raise ArgumentError.new("#{k.inspect} is not a supported option in DataMapper::Property::PROPERTY_OPTIONS") unless PROPERTY_OPTIONS.include?(k)
      end
    end
    
    def determine_visibility!
      @reader_visibility = @options[:reader] || @options[:accessor] || :public
      @writer_visibility = @options[:writer] || @options[:accessor] || :public
      @writer_visibility = :protected if @options[:protected]
      @writer_visibility = :private if @options[:private]
      raise(ArgumentError.new, "property visibility must be :public, :protected, or :private") unless VISIBILITY_OPTIONS.include?(@reader_visibility) && VISIBILITY_OPTIONS.include?(@writer_visibility)
    end
    
    def create_getter!
      if lazy?
        klass.class_eval <<-EOS
        #{reader_visibility.to_s}
        def #{name}
          lazy_load!(#{name.inspect})
          class << self;
            attr_accessor #{name.inspect}
          end
          @#{name}
        end
        EOS
      else
        klass.class_eval <<-EOS
        #{reader_visibility.to_s}
        def #{name}
          #{instance_variable_name}
        end
        EOS
      end
      if type == :boolean
        klass.class_eval <<-EOS
        #{reader_visibility.to_s}
        def #{name.to_s.ensure_ends_with('?')}
          #{instance_variable_name}
        end
        EOS
      end
    rescue SyntaxError
      raise SyntaxError.new(column)
    end
    
    def create_setter!
      if lazy?
        klass.class_eval <<-EOS
        #{writer_visibility.to_s}
        def #{name}=(value)
          class << self;
            attr_accessor #{name.inspect}
          end
          @#{name} = value
        end
        EOS
      else
        klass.class_eval <<-EOS
        #{writer_visibility.to_s}
        def #{name}=(value)
          #{instance_variable_name} = value
        end
        EOS
      end
    rescue SyntaxError
      raise SyntaxError.new(column)
    end
    
    AUTO_VALIDATIONS = {
      :nullable => lambda { |k,v| "validates_presence_of :#{k}" if v == false },
      :size => lambda { |k,v| "validates_length_of :#{k}, " + (v.is_a?(Range) ? ":minimum => #{v.first}, :maximum => #{v.last}" : ":maximum => #{v}") },
      :format => lambda { |k, v| "validates_format_of :#{k}, :with => #{v.inspect}" }
    }
    
    AUTO_VALIDATIONS[:length] = AUTO_VALIDATIONS[:size].dup
    
    def auto_validations!
      AUTO_VALIDATIONS.each do |key, value|
        next unless options.has_key?(key)
        validation = value.call(name, options[key])
        next if validation.empty?
        klass.class_eval <<-EOS
        begin
          #{validation}
        rescue ArgumentError => e
          throw e unless e.message =~ /specify a unique key/
        end
        EOS
      end
    end
    
    def klass
      @klass
    end
    
    def column
      database.table(klass)[@name]
    end
     
    def name
      column.name
    end
    
    def instance_variable_name
      column.instance_variable_name
    end
    
    def type
      column.type
    end
    
    def options
      column.options
    end
    
    def reader_visibility
      @reader_visibility
    end
    
    def writer_visibility
      @writer_visibility
    end
    
    def lazy?
      column.lazy?
    end
  end
end