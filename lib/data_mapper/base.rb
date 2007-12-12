require 'data_mapper/property'
require 'data_mapper/support/active_record_impersonation'
require 'data_mapper/support/serialization'
require 'data_mapper/validations'
require 'data_mapper/associations'
require 'data_mapper/callbacks'
require 'data_mapper/embedded_value'
require 'data_mapper/auto_migrations'
require 'data_mapper/dependency_queue'
require 'data_mapper/support/struct'

begin
  require 'ferret'
rescue LoadError
end

module DataMapper

  class Base
    
    # This probably needs to be protected
    attr_accessor :loaded_set
    
    include CallbacksHelper
    include Support::ActiveRecordImpersonation
    include Support::Serialization
    include Validations
    include Associations
    
    # Track classes that inherit from DataMapper::Base.
    def self.subclasses
      @subclasses || (@subclasses = [])
    end
    
    def self.auto_migrate!
      subclasses.each do |subclass|
        subclass.auto_migrate!
      end
    end
    
    def self.dependencies
      @dependency_queue || (@dependency_queue = DependencyQueue.new) 
    end
    
    def self.inherited(klass)
      klass.instance_variable_set('@properties', [])
      
      klass.send :extend, AutoMigrations
      DataMapper::Base::subclasses << klass
      klass.send(:undef_method, :id)
      
      # When this class is sub-classed, copy the declared columns.
      klass.class_eval do
        def self.subclasses
          @subclasses || (@subclasses = [])
        end
        
        def self.inherited(subclass)
          
          super_table = database.table(self)
          
          if super_table.type_column.nil?
            super_table.add_column(:type, :class, {})
          end
          
          subclass.instance_variable_set("@callbacks", self.callbacks.dup)
          
          self::subclasses << subclass
        end
      end
    end
    
    def self.logger
      database.logger
    end
    
    def logger
      self.class.logger
    end
    
    def self.transaction
      yield
    end
    
    def self.properties
      @properties
    end
    
    # Allows you to override the table name for a model.
    # EXAMPLE:
    #   class WorkItem
    #     set_table_name 't_work_item_list'
    #   end
    def self.set_table_name(value)
      database.schema[self].name = value
    end
    
    def initialize(details = nil)
      
      case details
      when Hash then self.attributes = details
      when DataMapper::Base then self.unsafe_attributes = details.attributes
      when Struct then self.unsafe_attributes = details.attributes
      when NilClass then nil
      end
    end
    
    # NOTE: check is only for psql, so maybe the postgres adapter should define
    # its own property options. currently it will produce a warning tho since
    # PROPERTY_OPTIONS is a constant
    PROPERTY_OPTIONS = [
      :public, :protected, :private, :accessor, :reader, :writer,
      :lazy, :default, :nullable, :key, :serial, :column, :size, :length,
      :index, :check
    ]
    
    # Adds property accessors for a field that you'd like to be able to modify.  The DataMapper doesn't
    # use the table schema to infer accessors, you must explicity call #property to add field accessors
    # to your model.
    #
    # EXAMPLE:
    #   class CellProvider
    #     property :name, :string
    #     property :rating, :integer
    #   end
    #
    #   att = CellProvider.new(:name => 'AT&T')
    #   att.rating = 3
    #   puts att.name, att.rating
    #
    #   => AT&T
    #   => 3
    #
    # OPTIONS:
    #   * <tt>lazy</tt>: Lazy load the specified property (:lazy => true). False by default.
    #   * <tt>accessor</tt>: Set method visibility for the property accessors. Affects both 
    #   reader and writer. Allowable values are :public, :protected, :private. Defaults to 
    #   :public
    #   * <tt>reader</tt>: Like the accessor option but affects only the property reader.
    #   * <tt>writer</tt>: Like the accessor option but affects only the property writer.
    #   * <tt>protected</tt>: Alias for :reader => :public, :writer => :protected
    #   * <tt>private</tt>: Alias for :reader => :public, :writer => :private
    def self.property(name, type, options = {})
      
      options.each_pair do |k,v|
        raise ArgumentError.new("#{k.inspect} is not a supported option in DataMapper::Base::PROPERTY_OPTIONS") unless PROPERTY_OPTIONS.include?(k)
      end
      
      visibility_options = [:public, :protected, :private]
      reader_visibility = options[:reader] || options[:accessor] || :public
      writer_visibility = options[:writer] || options[:accessor] || :public
      writer_visibility = :protected if options[:protected]
      writer_visibility = :private if options[:private]

      raise(ArgumentError.new, "property visibility must be :public, :protected, or :private") unless visibility_options.include?(reader_visibility) && visibility_options.include?(writer_visibility)

      mapping = database.schema[self].add_column(name.to_s.sub(/\?$/, '').to_sym, type, options)

      property_getter(mapping, reader_visibility)
      property_setter(mapping, writer_visibility)
      
      if MAGIC_PROPERTIES.has_key?(name)
        class_eval(&MAGIC_PROPERTIES[name])
      end
      
      return name
    end
    
    MAGIC_PROPERTIES = {
      :updated_at => lambda { before_save { |x| x.updated_at = Time::now } },
      :updated_on => lambda { before_save { |x| x.updated_on = Date::today } },
      :created_at => lambda { before_create { |x| x.created_at = Time::now } },
      :created_on => lambda { before_create { |x| x.created_on = Date::today } }
    }
    
    # An embedded value maps the values of an object to fields in the record of the object's owner.
    # #embed takes a symbol to define the embedded class, options, and an optional block. See 
    # examples for use cases.
    # 
    # EXAMPLE:
    #   class CellPhone < DataMapper::Base
    #     property :number, :string
    #
    #     embed :owner, :prefix => true do
    #       property :name, :string
    #       property :address, :string
    #     end
    #   end
    #
    #   my_phone = CellPhone.new
    #   my_phone.owner.name = "Nick"
    #   puts my_phone.owner.name
    #
    #   => Nick
    #
    # OPTIONS:
    #   * <tt>prefix</tt>: define a column prefix, so instead of mapping :address to an 'address' 
    #   column, it would map to 'owner_address' in the example above. If :prefix => true is 
    #   specified, the prefix will be the name of the symbol given as the first parameter. If the
    #   prefix is a string the specified string will be used for the prefix.
    #   * <tt>lazy</tt>: lazy-load all embedded values at the same time. :lazy => true to enable.
    #   Disabled (false) by default.
    #   * <tt>accessor</tt>: Set method visibility for all embedded properties. Affects both
    #   reader and writer. Allowable values are :public, :protected, :private. Defaults to :public
    #   * <tt>reader</tt>: Like the accessor option but affects only embedded property readers.
    #   * <tt>writer</tt>: Like the accessor option but affects only embedded property writers.
    #   * <tt>protected</tt>: Alias for :reader => :public, :writer => :protected
    #   * <tt>private</tt>: Alias for :reader => :public, :writer => :private
    #
    def self.embed(name, options = {}, &block)
      EmbeddedValue::define(self, name, options, &block)
    end
    
    # Creates indexes for an arbitrary number of database columns. Note that
    # it also is possible to specify indexes directly for each property.
    # 
    # === EXAMPLE:
    #
    #   class Person < DataMapper::Base
    #     property :name, :string
    #     property :age, :integer, :nullable => false
    #     property :occupation, :string
    #     property :notes, :text, :lazy => true
    #
    #     add_index :age, :occupation
    #   end
    #
    # === QUICK INDEX EXAMPLES:
    # * property :name, :index => true
    # * property :name, :index => :unique
    def self.add_index(*indexes)
      database.schema[self].columns.each do |column|
        if indexes.include? column.name
          column.index = true # let the column know that it should be indexed
          next                # now lets look at the next one
        end
      end
    end

    def self.property_getter(mapping, visibility = :public)
      if mapping.lazy?
        class_eval <<-EOS
          #{visibility.to_s}
          def #{mapping.name}
            lazy_load!(#{mapping.name.inspect})
            class << self;
              attr_accessor #{mapping.name.inspect}
            end
            @#{mapping.name}
          end
        EOS
      else
        class_eval("#{visibility.to_s}; def #{mapping.name}; #{mapping.instance_variable_name} end") unless [ :public, :private, :protected ].include?(mapping.name)
      end
      
      if mapping.type == :boolean
        class_eval("#{visibility.to_s}; def #{mapping.name}?; #{mapping.instance_variable_name} end")
      end
      
    rescue SyntaxError
      raise SyntaxError.new(mapping)
    end
    
    def self.property_setter(mapping, visibility = :public)
      if mapping.lazy?
        class_eval <<-EOS
          #{visibility.to_s}
          def #{mapping.name}=(value)
            class << self;
              attr_accessor #{mapping.name.inspect}
            end
            @#{mapping.name} = value
          end
        EOS
      else
        class_eval("#{visibility.to_s}; def #{mapping.name}=(value); #{mapping.instance_variable_name} = value end")
      end
    rescue SyntaxError
      raise SyntaxError.new(mapping)
    end
    
    # Lazy-loads the attributes for a loaded_set, then overwrites the accessors
    # for the named methods so that the lazy_loading is skipped the second time.
    def lazy_load!(*names)
      
      names = names.map { |name| name.to_sym }.reject { |name| lazy_loaded_attributes.include?(name) }
      
      reset_attribute = lambda do |instance|
        singleton_class = (class << instance; self end)
        names.each do |name|
          instance.lazy_loaded_attributes << name
          singleton_class.send(:attr_accessor, name)
        end
      end
      
      unless names.empty? || new_record? || loaded_set.nil?
        
        key = database_context.table(self.class).key.to_sym
        keys_to_select = loaded_set.map do |instance|
          instance.send(key)
        end
        
        database_context.all(
          self.class,
          :select => ([key] + names),
          :reload => true,
          key => keys_to_select
        ).each(&reset_attribute)
      else
        reset_attribute[self]
      end
      
    end
    
    def new_record?
      @new_record.nil? || @new_record
    end

    def ==(other)
      other.is_a?(self.class) && private_attributes == other.send(:private_attributes)
    end
    
    # Returns the difference between two objects, in terms of their attributes. 
    def ^(other)
      results = {}
      
      self_attributes, other_attributes = attributes, other.attributes
      
      self_attributes.each_pair do |k,v|
        other_value = other_attributes[k]
        unless v == other_value
          results[k] = [v, other_value]
        end
      end
      
      results      
    end
    
    def lazy_loaded_attributes
      @lazy_loaded_attributes || @lazy_loaded_attributes = Set.new
    end
    
    def loaded_attributes
      pairs = {}
      
      database_context.table(self).columns.each do |column|
        pairs[column.name] = instance_variable_get(column.instance_variable_name)
      end
      
      pairs
    end
    
    def update_attributes(update_hash)
      self.attributes = update_hash
      self.save
    end
    
    def attributes
      pairs = {}
      
      database_context.table(self).columns.each do |column|
        if self.class.public_method_defined?(column.name)
          lazy_load!(column.name) if column.lazy?
          value = instance_variable_get(column.instance_variable_name)
          pairs[column.name] = column.type == :class ? value.to_s : value
        end
      end
      
      pairs
    end
    
    # Mass-assign mapped fields.
    def attributes=(values_hash)
      table = database_context.table(self.class)
      
      values_hash.delete_if do |key, value|
        !self.class.public_method_defined?("#{key}=")
      end.each_pair do |key, value|
        if respond_to?(key)
          send("#{key}=", value)
        elsif column = table[key]
          instance_variable_set(column.instance_variable_name, value)          
        end
      end
    end
    
    def unsafe_attributes=(values_hash)
      table = database_context.table(self.class)
      
      values_hash.each_pair do |key, value|
        if respond_to?(key)
          send("#{key}=", value)
        elsif column = table[key]
          instance_variable_set(column.instance_variable_name, value)          
        end
      end
    end
    
    def dirty?
      result = database_context.table(self).columns.any? do |column|
        if column.type == :object
          Marshal.dump(self.instance_variable_get(column.instance_variable_name)) != original_values[column.name]
        else
          self.instance_variable_get(column.instance_variable_name) != original_values[column.name]
        end
      end
      
      return true if result
      
      loaded_associations.any? do |loaded_association|
        loaded_association.dirty?
      end
    end

    def dirty_attributes
      pairs = {}
      
      database_context.table(self).columns.each do |column|
        value = instance_variable_get(column.instance_variable_name)
        if value != original_values[column.name] && (!new_record? || !column.serial?)
          pairs[column.name] = column.type != :object ? value : YAML.dump(value)
        end
      end
      
      pairs
    end
    
    def original_values
      @original_values || (@original_values = {})
    end
    
    def self.index
      @index || @index = Ferret::Index::Index.new(:path => "#{database.adapter.index_path}/#{name}")
    end
    
    def self.reindex!
      all.each do |record|
        index << record.attributes
      end
    end
    
    def self.search(phrase)
      ids = []
      
      query = "#{database.schema[self].columns.map(&:name).join('|')}:\"#{phrase}\""

      index.search_each(query) do |document_id, score|
        ids << index[document_id][:id]
      end
      return all(:id => ids)
    end
    
    def self.foreign_key
      Inflector.underscore(self.name) + "_id"
    end
    
    def self.table
      database.schema[self]
    end
    
    def inspect
      inspected_attributes = attributes.map { |k,v| "@#{k}=#{v.inspect}" }
      
      instance_variables.each do |name|
        if instance_variable_get(name).kind_of?(Associations::HasManyAssociation)
          inspected_attributes << "#{name}=#{instance_variable_get(name).inspect}"
        end
      end
      
      "#<%s:0x%x @new_record=%s, %s>" % [self.class.name, (object_id * 2), new_record?, inspected_attributes.join(', ')]
    end
    
    def loaded_associations
      @loaded_associations || @loaded_associations = []
    end
    
    def database_context=(value)
      @database_context = value
    end
    
    def database_context
      @database_context || ( @database_context = database )
    end
    
    def key=(value)
      key_column = database_context.table(self.class).key
      @__key = key_column.type_cast_value(value)
      instance_variable_set(key_column.instance_variable_name, @__key)
    end
    
    def key
      @__key || @__key = begin
        key_column = database_context.table(self.class).key
        key_column.type_cast_value(instance_variable_get(key_column.instance_variable_name))
      end
    end

    private

    # return all attributes, regardless of their visibility
    def private_attributes
      pairs = {}

      database_context.table(self).columns.each do |column|
        lazy_load!(column.name) if column.lazy?
        value = instance_variable_get(column.instance_variable_name)
        pairs[column.name] = column.type == :class ? value.to_s : value
      end

      pairs
    end
    
  end
  
end
