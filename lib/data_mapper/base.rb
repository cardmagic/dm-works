require 'data_mapper/property'
require 'data_mapper/support/active_record_impersonation'
require 'data_mapper/support/serialization'
require 'data_mapper/validations/validation_helper'
require 'data_mapper/associations'
require 'data_mapper/callbacks'
require 'data_mapper/embedded_value'
require 'data_mapper/auto_migrations'

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
    include Validations::ValidationHelper
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
          self::subclasses << subclass
        end
      end
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
      when DataMapper::Base then self.attributes = details.attributes
      when NilClass then nil
      end
    end
    
    # Adds property accessors for a field that you'd like to be able to modify.  The DataMapper doesn't
    # use the table schema to infer accessors, you must explicity call #property to add field accessors
    # to your model.
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
    def self.property(name, type, options = {})
      mapping = database.schema[self].add_column(name.to_s.sub(/\?$/, '').to_sym, type, options)
      property_getter(mapping)
      property_setter(mapping)
      
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
    # #embed takes a class name or a symbol, options, and an optional block. If you wish to pass it
    # a class, that class must inherit from DataMapper::EmbeddedValue. See examples for use cases.
    # 
    # EXAMPLE:
    #   class CellPhone < DataMapper::Base
    #     property :number, :string
    #
    #     embed :owner, :prefix => true do
    #       property :name, :string
    #       property :address, :string
    #     end
    #
    #     class Provider < DataMapper::EmbeddedValue
    #       property :name, :string
    #       property :code, :integer
    #
    #       def to_s
    #         "#{code} #{name}"
    #       end
    #     end
    # 
    #     embed Provider
    #   end
    #
    #   my_phone = CellPhone.new
    #   my_phone.owner.name = "Nick"
    #   my_phone.provider.name = "T-Mobile"
    #   my_phone.provider.code = 4444
    #   puts my_phone.owner.name
    #   puts my_phone.provider.to_s
    #
    #   => Nick
    #   => 4444 T-Mobile
    #
    # OPTIONS:
    #   * <tt>prefix</tt>: define a column prefix, so instead of mapping :address to an 'address' 
    #   column, it would map to 'owner_address' in the example above. If :prefix => true is 
    #   specified, the prefix will be the name of the symbol given as the first parameter. If the
    #   prefix is a string the specified string will be used for the prefix.
    #
    def self.embed(class_or_name, options = {}, &block)
      EmbeddedValue::define(self, class_or_name, options, &block)
    end

    def self.property_getter(mapping)      
      if mapping.lazy?
        class_eval <<-EOS
          def #{mapping.name}
            lazy_load!(#{mapping.name.inspect})
            @#{mapping.name}
          end
        EOS
      else
        class_eval("def #{mapping.name}; #{mapping.instance_variable_name} end")
      end
      
      if mapping.type == :boolean
        class_eval("alias #{mapping.name}? #{mapping.name}")
      end
    end
    
    def self.property_setter(mapping)
      if mapping.lazy?
        class_eval <<-EOS
          def #{mapping.name}=(value)
            class << self;
              attr_accessor #{mapping.name.inspect}
            end
            @#{mapping.name} = value
          end
        EOS
      else
        class_eval("def #{mapping.name}=(value); #{mapping.instance_variable_name} = value end")
      end
    end
    
    # Lazy-loads the attributes for a loaded_set, then overwrites the accessors
    # for the named methods so that the lazy_loading is skipped the second time.
    def lazy_load!(*names)
      
      reset_attribute = lambda do |instance|
        singleton_class = (class << instance; self end)
        names.each do |name|
          singleton_class.send(:attr_accessor, name)
        end
      end
      
      unless new_record? || loaded_set.nil?
        session.all(
          self.class,
          :select => ([:id] + names),
          :reload => true,
          :id => loaded_set.map(&:id)
        ).each(&reset_attribute)
      else
        reset_attribute[self]
      end
      
    end
    
    def new_record?
      @new_record.nil? || @new_record
    end
    
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
    
    def loaded_attributes
      pairs = {}
      
      session.table(self).columns.each do |column|
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
      
      session.table(self).columns.each do |column|
        lazy_load!(column.name) if column.lazy?
        value = instance_variable_get(column.instance_variable_name)
        pairs[column.name] = column.type == :class ? value.to_s : value
      end
      
      pairs
    end
    
    # Mass-assign mapped fields.
    def attributes=(values_hash)
      table = session.schema[self.class]
      
      values_hash.reject do |key, value|
        protected_attribute? key
      end.each_pair do |key, value|
        if respond_to?(key)
          send("#{key}=", value)
        elsif column = table[key]
          instance_variable_set(column.instance_variable_name, value)          
        end
      end
    end
    
    def dirty?(name = nil)
      if name.nil?
        session.table(self).columns.any? do |column|
          self.instance_variable_get(column.instance_variable_name) != original_values[column.name]
        end || loaded_associations.any? do |loaded_association|
          if loaded_association.respond_to?(:dirty?)
            loaded_association.dirty?
          else
            false
          end
        end
      else
        key = name.kind_of?(Symbol) ? name : name.to_sym
        self.instance_variable_get("@#{name}") != original_values[key]
      end
    end

    def dirty_attributes
      pairs = {}
      
      if new_record?
        session.table(self).columns.each do |column|
          unless (value = instance_variable_get(column.instance_variable_name)).nil?
            pairs[column.name] = value
          end
        end
      else
        session.table(self).columns.each do |column|
          if (value = instance_variable_get(column.instance_variable_name)) != original_values[column.name]
            pairs[column.name] = value
          end
        end
      end
      
      pairs
    end
    
    def original_values
      @original_values || (@original_values = {})
    end
    
    def protected_attribute?(key)
      self.class.protected_attributes.include?(key.kind_of?(Symbol) ? key : key.to_sym)
    end
    
    def self.protected_attributes
      @protected_attributes ||= []
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
    
    def self.protect(*keys)
      keys.each { |key| protected_attributes << key.to_sym }
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
    
    def session=(value)
      @session = value
    end
    
    def session
      @session || ( @session = database )
    end
    
    def key=(value)
      key_column = session.schema[self.class].key
      @__key = key_column.type_cast_value(value)
      instance_variable_set(key_column.instance_variable_name, @__key)
    end
    
    def key
      @__key || @__key = begin
        key_column = session.schema[self.class].key
        key_column.type_cast_value(instance_variable_get(key_column.instance_variable_name))
      end
    end
    
    
  end
  
end
