module DataMapper
  class Property
    
    # NOTE: check is only for psql, so maybe the postgres adapter should define
    # its own property options. currently it will produce a warning tho since
    # PROPERTY_OPTIONS is a constant
    PROPERTY_OPTIONS = [
      :public, :protected, :private, :accessor, :reader, :writer,
      :lazy, :default, :nullable, :key, :serial, :column, :size, :length,
      :index, :check, :ordinal
    ]
    
    VISIBILITY_OPTIONS = [:public, :protected, :private]
    
    MAGIC_PROPERTIES = {
      :updated_at => lambda { before_save { |x| x.updated_at = Time::now } },
      :updated_on => lambda { before_save { |x| x.updated_on = Date::today } },
      :created_at => lambda { before_create { |x| x.created_at = Time::now } },
      :created_on => lambda { before_create { |x| x.created_on = Date::today } }
    }
    
    def initialize(table, name, type, options)
      
      @table, @options = table, options
      symbolized_name = name.to_s.sub(/\?$/, '').to_sym
      
      validate_options!
      determine_visibility!
      
      table::ATTRIBUTES << symbolized_name
      
      @column = database.schema[table].add_column(symbolized_name, type, options)
      
      create_getter!
      create_setter!
      
      create_magic_properties
      
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
        table.class_eval <<-EOS
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
        table.class_eval <<-EOS
        #{reader_visibility.to_s}
        def #{name}
          #{instance_variable_name}
        end
        EOS
      end
      if type == :boolean
        table.class_eval <<-EOS
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
        table.class_eval <<-EOS
        #{writer_visibility.to_s}
        def #{name}=(value)
          class << self;
            attr_accessor #{name.inspect}
          end
          @#{name} = value
        end
        EOS
      else
        table.class_eval <<-EOS
        #{writer_visibility.to_s}
        def #{name}=(value)
          #{instance_variable_name} = value
        end
        EOS
      end
    rescue SyntaxError
      raise SyntaxError.new(column)
    end
    
    def create_magic_properties
      if MAGIC_PROPERTIES.has_key?(name)
        table.class_eval(&MAGIC_PROPERTIES[name])
      end
    end
    
    def table
      @table
    end
    
    def column
      @column
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
      column[:options]
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