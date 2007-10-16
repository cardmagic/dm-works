require 'data_mapper/support/active_record_impersonation'
require 'data_mapper/validations/validation_helper'
require 'data_mapper/associations'
require 'data_mapper/callbacks'
require 'data_mapper/embedded_value'

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
      DataMapper::Base::subclasses << klass
      klass.send(:undef_method, :id)      
      
      # When this class is sub-classed, copy the declared columns.
      klass.class_eval do
        
        def self.auto_migrate!
          if self::subclasses.empty?
            database.schema[self].drop!
            database.save(self)
          else
            schema = database.schema
            columns = self::subclasses.inject(schema[self].columns) do |span, subclass|
              span + schema[subclass].columns
            end
            
            table_name = schema[self].name.to_s
            table = schema[table_name]
            columns.each do |column|
              table.add_column(column.name, column.type, column.options)
            end
            
            table.drop!
            table.create!
          end
        end
        
        def self.subclasses
          @subclasses || (@subclasses = [])
        end
        
        def self.inherited(subclass)
          
          self::subclasses << subclass
          
          database.table(self).columns.each do |c|
            subclass.property(c.name, c.type, c.options)
            subclass.before_create do
              @type = self.class
            end if c.name == :type
          end          
        end
      end
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
      mapping = database.schema[self].add_column(name, type, options)
      property_getter(name, mapping)
      property_setter(name, mapping)
      return name
    end
    
    def self.embed(class_or_name, &block)
      EmbeddedValue::define(self, class_or_name, &block)
    end

    def self.property_getter(name, mapping)
      if mapping.lazy?
        class_eval <<-EOS
          def #{name}
            lazy_load!(#{name.inspect})
            @#{name}
          end
        EOS
      else
        class_eval("def #{name}; #{mapping.instance_variable_name} end")
      end
    end
    
    def self.property_setter(name, mapping)
      if mapping.lazy?
        class_eval <<-EOS
          def #{name.to_s.sub(/\?$/, '')}=(value)
            class << self;
              attr_accessor #{name.inspect}
            end
            @#{name} = value
          end
        EOS
      else
        class_eval("def #{name.to_s.sub(/\?$/, '')}=(value); #{mapping.instance_variable_name} = value end")
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
    
    def loaded_attributes
      pairs = {}
      
      session.table(self).columns.each do |column|
        pairs[column.name] = instance_variable_get(column.instance_variable_name)
      end
      
      pairs
    end
    
    def attributes
      pairs = {}
      
      session.table(self).columns.each do |column|
        lazy_load!(column.name) if column.lazy?
        pairs[column.name] = instance_variable_get(column.instance_variable_name)
      end
      
      pairs
    end
    
    # Mass-assign mapped fields.
    def attributes=(values_hash)
      table = session.schema[self.class]
      
      values_hash.reject do |key, value|
        protected_attribute? key
      end.each_pair do |key, value|
        if column = table[key]
          instance_variable_set(column.instance_variable_name, value)
        else
          send("#{key}=", value)
        end
      end
    end
    
    def dirty?(name = nil)
      if name.nil?
        session.table(self).columns.any? do |column|
          if value = self.instance_variable_get(column.instance_variable_name)
            value.hash != original_hashes[column.name]
          else
            false
          end
        end || loaded_associations.any? do |loaded_association|
          if loaded_association.respond_to?(:dirty?)
            loaded_association.dirty?
          else
            false
          end
        end
      else
        key = name.kind_of?(Symbol) ? name : name.to_sym
        self.instance_variable_get("@#{name}").hash != original_hashes[key]
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
          if (value = instance_variable_get(column.instance_variable_name)).hash != original_hashes[column.name]
            pairs[column.name] = value
          end
        end
      end
      
      pairs
    end
    
    def original_hashes
      @original_hashes || (@original_hashes = {})
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