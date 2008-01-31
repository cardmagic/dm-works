
module DataMapper
  
# = Properties
# A model's properties are not introspected from the fields in the database, in fact the reverse happens. You declare the properties for a model inside it's class definition, which is then used to generate or map to the fields in the database.
# 
# This has a few advantages. First, it means that a model's properties are documented in the model itself, not a migration or XML file. If you've ever been annoyed at having to look in a schema file to see the list of properties and types for a model, you'll find this particularly useful.
# 
# Second, it lets you limit access to properties using Ruby's access semantics. Properties can be declared public, private or protected. They are public by default.
# 
# Third, by only touching the columns it knows about, Datamapper plays well with legacy databases and other applications utilizing the same database.  
#
# == Declaring Properties
# Inside your class, you call the property method for each property you want to add. The only two required arguments are the name and type, everything else is optional.
# 
#   class Post < DataMapper::Base
#     property :title,   :string, :nullable => false # Cannot be null
#     property :publish, :boolen, :default  => false # Default value for new records is false
#   end
# 
# == Limiting Access
# Access for properties is defined using the same semantics as Ruby. Accessors are public by default, but you can declare them as private or protected if you need. You can set access using the :accessor option.
# 
#  class Post < DataMapper::Base
#    property :title,  :string, :accessor => :private   # Both reader and writer are private
#    property :body,   :text,   :accessor => :protected # Both reader and writer are protected
#  end
# 
# You also have more fine grained control over how you declare access. You can for example have a public reader and private writer for a property by using the :writer and :reader options
# 
#  class Post < DataMapper::Base
#    property :title, :string, :writer => :private    # Only writer is private
#    property :tags,  :string, :reader => :protected  # Only reader is protected
#  end
#
# == Overriding Accessors
# When a property has declared accessors for getting and setting, it's values are added to the model. Just like using attr_accessor, you can over-ride these with your own custom accessors. It's a simple matter of adding an accessor after the property declaration.
# 
#  class Post < DataMapper::Base
#    property :title,  :string
#    
#    def title=(new_title)
#      raise ArgumentError if new_title != 'Luke is Awesome'
#      @title = new_title
#    end
#  end
#
# == Lazy Loading
# Properties can be configured to be lazy loading. A lazily loaded property is not requested from the database by default. Instead it is only loaded when it's accessor is called for the first time. This means you can stop default queries from being greedy, a particular problem with text fields. Text fields are lazily loaded by default, which you can over-ride if you need.
# 
#  class Post < DataMapper::Base
#    property :title,  :string   # Loads normally
#    property :body,   :text     # Is lazily loaded by default
#  end
# 
# If you want to over-ride the lazy loading on any field you can set it to true or false with the :lazy option.
# 
#  class Post < DataMapper::Base
#    property :title,  :string               # Loads normally
#    property :body,   :text, :lazy => false # The default is now over-ridden
#  end
#
# When working with objects inside of another objects associations and you call the accessor for one item's lazy-loaded property, all of the objects in the association have their accessors loaded up so they're ready to go.  When iterating over an object's assocations, you STILL only make 2 queries to the database!
#
# == Keys
# Properties can be declared as primary or natural keys on a table.  By default, Datamapper will assume <tt>:id</tt> and create it if you don't have it.  You can, however, declare a property as the primary key of the table:
#
#  property :legacy_pk, :string, :key => true
#
# This is roughly equivalent to Activerecord's <tt>set_primary_key</tt>, though non-integer data types may be used, thus Datamapper supports natural keys. When a property is declared as a natural key, accessing the object using the indexer syntax <tt>Class[key]</tt> remains valid.
#
#   User[1] when :id is the primary key on the users table
#   User['bill'] when :name is the primary (natural) key on the users table
#
# == Inferred Validations
# When properties are declared with specific column restrictions, Datamapper will inferred a few validation rules for values assigned to that property.
#
#  property :title, :string, :length => 250
#  # => infers 'validates_length_of :title, :minimum => 0, :maximum => 250'
#
#  property :title, :string, :nullable => false
#  # => infers 'validates_presense_of :title
#
#  property :email, :string, :format => :email_address
#  # => infers 'validates_format_of :email, :with => :email_address
#
#  property :title, :string, :length => 255, :nullable => false
#  # => infers both 'validates_length_of' as well as 'validates_presense_of'
#  #    better: property :title, :string, :length => 1..255
#
# For more information about validations, visit the Validatable documentation.
# == Embedded Values
# As an alternative to serializing non-mappable data out into a text column on your table, consider an EmbeddedValue.
#
# == Misc. Notes
# * Properties declared as strings will default to a length of 50, rather than 255 (typical max varchar column size).  To overload the default, pass <tt>:length => 255</tt> or <tt>:length => 0..255</tt>.  Since Datamapper does not introspect for properties, this means that legacy database tables may need their <tt>:string</tt> columns defined with a <tt>:length</tt> so that DM does not inadvertantly truncate data.
# * You may declare a Property with the data-type of <tt>:class</tt>.  see SingleTableInheritance for more on how to use <tt>:class</tt> columns.
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
      
      @klass, @name, @type, @options = klass, name.to_sym, type, options
      @symbolized_name = name.to_s.sub(/\?$/, '').to_sym
      
      validate_type!
      validate_options!
      determine_visibility!
      
      database.schema[klass].add_column(@symbolized_name, @type, @options)
      klass::ATTRIBUTES << @symbolized_name
      
      create_getter!
      create_setter!
      auto_validations!
      
    end
    
    def validate_type! # :nodoc:
      adapter_class = database.adapter.class
      raise ArgumentError.new("#{@type.inspect} is not a supported type in the database adapter. Valid types are:\n #{adapter_class::TYPES.keys.inspect}") unless adapter_class::TYPES.has_key?(@type)
    end
    
    def validate_options! # :nodoc:
      @options.each_pair do |k,v|
        raise ArgumentError.new("#{k.inspect} is not a supported option in DataMapper::Property::PROPERTY_OPTIONS") unless PROPERTY_OPTIONS.include?(k)
      end
    end
    
    def determine_visibility! # :nodoc:
      @reader_visibility = @options[:reader] || @options[:accessor] || :public
      @writer_visibility = @options[:writer] || @options[:accessor] || :public
      @writer_visibility = :protected if @options[:protected]
      @writer_visibility = :private if @options[:private]
      raise(ArgumentError.new, "property visibility must be :public, :protected, or :private") unless VISIBILITY_OPTIONS.include?(@reader_visibility) && VISIBILITY_OPTIONS.include?(@writer_visibility)
    end
    
    # defines the getter for the property
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
    
    # defines the setter for the property
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
    
    # :NOTE: :length may also be used in place of :size
    AUTO_VALIDATIONS = {
      :nullable => lambda { |k,v| "validates_presence_of :#{k}" if v == false },
      :size => lambda { |k,v| "validates_length_of :#{k}, " + (v.is_a?(Range) ? ":minimum => #{v.first}, :maximum => #{v.last}" : ":maximum => #{v}") },
      :format => lambda { |k, v| "validates_format_of :#{k}, :with => #{v.inspect}" }
    }
    
    AUTO_VALIDATIONS[:length] = AUTO_VALIDATIONS[:size].dup
    
    # defines the inferred validations given a property definition.
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
      column = database.table(klass)[@name]
      raise StandardError.new("#{@name.inspect} is not a valid column name") unless column
      return column
    end
     
    def name
      @name
    end
    
    def instance_variable_name # :nodoc:
      column.instance_variable_name
    end
    
    def type
      column.type
    end
    
    def options
      column.options
    end
    
    def reader_visibility # :nodoc:
      @reader_visibility
    end
    
    def writer_visibility # :nodoc:
      @writer_visibility
    end
    
    def lazy?
      column.lazy?
    end
  end
end