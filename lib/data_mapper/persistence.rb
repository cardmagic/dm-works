require 'data_mapper/property'
require 'data_mapper/attributes'
require 'data_mapper/support/serialization'
require 'data_mapper/validations'
require 'data_mapper/associations'
require 'data_mapper/callbacks'
require 'data_mapper/embedded_value'
require 'data_mapper/auto_migrations'
require 'data_mapper/dependency_queue'
require 'data_mapper/support/struct'

module DataMapper
  # See DataMapper::Persistence::ClassMethods for DataMapper's DSL documentation.
  module Persistence

    class IncompleteModelDefinitionError < StandardError
    end

    # This probably needs to be protected
    attr_accessor :loaded_set

    include Comparable

    def self.included(klass)

      klass.extend(ClassMethods)
      klass.extend(ConvenienceMethods::ClassMethods)

      klass.send(:include, ConvenienceMethods::InstanceMethods)
      klass.send(:include, Attributes)
      klass.send(:include, Associations)
      klass.send(:include, Validations)
      klass.send(:include, CallbacksHelper)
      klass.send(:include, Support::Serialization)

      klass.instance_variable_set('@properties', [])

      klass.send :extend, AutoMigrations
      klass.subclasses
      DataMapper::Persistence::subclasses << klass unless klass == DataMapper::Base
      klass.send(:undef_method, :id) if method_defined?(:id)

      # When this class is sub-classed, copy the declared columns.
      klass.class_eval do
        def self.subclasses
          @subclasses || (@subclasses = Support::TypedSet.new(Class))
        end

        def self.inherited(subclass)
          super_table = database.table(self)

          if super_table.type_column.nil?
            super_table.add_column(:type, :class, {})
          end

          subclass.instance_variable_set('@properties', self.instance_variable_get("@properties").dup)
          subclass.instance_variable_set("@callbacks", self.callbacks.dup)

          self::subclasses << subclass
        end

        def self.persistent?
          true
        end
      end
    end

    def self.auto_migrate!
      subclasses.each do |subclass|
        subclass.auto_migrate!
      end
    end

    # Drops all tables known by the schema
    def self.drop_all_tables!
      database.adapter.schema.each do |table|
        table.drop!
      end
    end

    # Track classes that include this module.
    def self.subclasses
      @subclasses || (@subclasses = Support::TypedSet.new(Class))
    end

    def self.dependencies
      @dependency_queue || (@dependency_queue = DependencyQueue.new)
    end

    def initialize(details = nil)
      check_for_properties!
      if details
        case details
        when Hash then self.attributes = details
        when details.respond_to?(:persistent?) then self.private_attributes = details.attributes
        when Struct then self.private_attributes = details.attributes
        end
      end
    end

    def check_for_properties!
      raise IncompleteModelDefinitionError.new("Models must have at least one property to be initialized.") if self.class.properties.empty?
    end

    module ConvenienceMethods
      module InstanceMethods
        def save
          database_context.save(self)
        end

        def save!
          raise ValidationError.new(errors) unless save
          return true
        end

        def reload!(cols = nil)
          database_context.first(self.class, key, :select => ([self.class.table.key.to_sym] + (cols || original_values.keys)).uniq, :reload => true)
          self.loaded_associations.each { |association| association.reload! }
          self
        end
        alias reload reload!

        def destroy!
          database_context.destroy(self)
        end
      end

      module ClassMethods
        
        # Attempts to find an object using options passed in in search_attributes, and falls back to creating the object if it can't find it.
        # Examples:
        #
        #   Widget.find_or_create(:title => 'Steak Knife', :length => 8)
        #
        #   Widget.find_or_create({:title => 'Butter Knife'}, {:length => 5})
        # NOTE: If the attributes specified in to <tt>search_attributes</tt> and <tt>create_attributes</tt> by do not make up a valid object, creation will fail with a validation error.
        def find_or_create(search_attributes, create_attributes = {})
          first(search_attributes) || create(search_attributes.merge(create_attributes))
        end

        # returns an array of objects matching <tt>options</tt>.  There are many ways to pass in <tt>options</tt>, so examples are in order.  Output on the right indicates how the passed-in <tt>options</tt> affects the resulting query.
        #
        # Basics:
        #   Widget.all                                          # => no conditions
        #   Widget.all :order => 'created_at desc'              # => ORDER BY created_at desc
        #   Widget.all :limit => 10                             # => LIMIT 10
        #   Widget.all :offset => 100                           # => OFFSET 100
        #   Widget.all :include => [:parts]                     # => performs the JOIN according to
        #                                                            its association with Parts
        #
        # Any non-standard options are assumed to be column names and are ANDed together: 
        #   Widget.all :age => 10                               # => WHERE age = 10
        #   Widget.all :age => 10, :title => 'Toy'              # => WHERE age = 10 AND title = 'Toy'
        #
        # Using Symbol Operators[link:classes/DataMapper/Support/Symbol/Operator.html]:
        #   Widget.all :age.gt => 20                            # => WHERE age > 10
        #   Widget.all :age.gte => 20, :name.like => '%Toy%'    # => WHERE age >= 10 and name like '%Toy%'
        # 
        # Variations of syntax include the :conditions => {} as well as interpolated arrays
        #   Widget.all :conditions => {:age => 10}              # => WHERE age = 10
        #   Widget.all :conditions => ["age = ?", 10]           # => WHERE age = 10
        #
        # Syntaxes can be mixed-and-matched as well
        #   Widget.all :conditions => ["age = ?", 10], :title => 'Toy'
        #   # => WHERE age = 10 AND title = 'Toy'
        #
        def all(options = {})
          database.all(self, options)
        end

        def each(options = {}, &b)
          raise ArgumentError.new(":offset is not supported with the #each method") if options.has_key?(:offset)

          offset = 0
          limit = options[:limit] || (self::const_defined?('DEFAULT_LIMIT') ? self::DEFAULT_LIMIT : 500)

          until (results = all(options.merge(:limit => limit, :offset => offset))).empty?
            results.each(&b)
            offset += limit
          end
        end

        # accepts the same arguments as all(), though instead of returning an array, it returns the first value
        def first(*args)
          database.first(self, *args)
        end

        # returns the count of rows that match the given options hash.  See all() for a list of possible arguments.
        # NOTE: discards <tt>:offset</tt>, <tt>:limit</tt>, <tt>:order</tt>
        def count(*args)
          database.count(self, *args)
        end

        def delete_all
          database.delete_all(self)
        end

        def truncate!
          database.truncate(self)
        end

        def find(type_or_id, options = {})
          case type_or_id
            when :first then first(options)
            when :all then all(options)
            else first(type_or_id, options)
          end
        end
        
        # supply this method with the full SQL you wish to search on, and it will return an array of Structs with your results set in them.
        #
        # NOTE: this does NOT return objects of a specific type, but rather Struct objects with as many attributes as what you requested in your full SQL query. These structs are read-only.
        #
        # If you only indicate you want 1 specific column, Datamapper and DataObjects will do their best to type-cast the result as best they can, rather than supplying you with an array of length 1 containing Structs with 1 attribute.
        def find_by_sql(*args)
          DataMapper::database.query(*args)
        end

        # finds a single row from the database by it's primary key.  If you declared a property with <tt>:key => true</tt>, it's safe to use here.
        # Example:
        #   Widget.get(100)                                        # => widget with the primary key of 100
        #   Widget.get('Toy')                                      # => widget with the primary natural key of 'Toy'
        def get(*keys)
          database.get(self, keys)
        end

        # synonym for get()
        # Example:
        #   Widget[100]                                            # => widget with the primary key of 100
        def [](*keys)
          # Eventually this ArgumentError should be removed. It's only here to help
          # migrate users away from the [options_hash] syntax, which is no longer supported.
          raise ArgumentError.new('Hash is not a valid key') if keys.size == 1 && keys.first.is_a?(Hash)
          instance = database.get(self, keys)
          raise ObjectNotFoundError.new() unless instance
          return instance
        end

        # creates (and saves) a new instance of the object.
        def create(attributes)
          instance = self.new
          instance.attributes = attributes
          instance.save
          instance
        end

        # the same as create(), though will raise an ObjectNotFoundError if the instance could not be saved
        def create!(attributes)
          instance = self.new
          instance.attributes = attributes
          instance.save
          raise ObjectNotFoundError.new(instance) if instance.new_record?
          instance
        end
      end
    end

    module ClassMethods

      # Track classes that include this module.
      def subclasses
        @subclasses || (@subclasses = [])
      end

      def logger
        database.logger
      end

      def transaction
        yield
      end

      def foreign_key
        Inflector.underscore(self.name) + "_id"
      end

      def extended(klass)
      end

      def table
        database.table(self)
      end

      # Adds property accessors for a field that you'd like to be able to modify.  The DataMapper doesn't
      # use the table schema to infer accessors, you must explicity call #property to add field accessors
      # to your model.  For more documentation, see Property
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

      def property(name, type, options = {})
        property = DataMapper::Property.new(self, name, type, options)
        @properties ||= []
        @properties << property
        property
      end

      # TODO: Figure out how to make EmbeddedValue work with new property code. EV relies on these next two methods.
      def property_getter(mapping, visibility = :public)
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
          class_eval("#{visibility.to_s}; def #{mapping.name.to_s.ensure_ends_with('?')}; #{mapping.instance_variable_name} end")
        end

      rescue SyntaxError
        raise SyntaxError.new(mapping)
      end

      def property_setter(mapping, visibility = :public)
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

      # Allows you to override the table name for a model.
      # EXAMPLE:
      #   class WorkItem
      #     set_table_name 't_work_item_list'
      #   end
      def set_table_name(value)
        database.table(self).name = value
      end
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
      def embed(name, options = {}, &block)
        EmbeddedValue::define(self, name, options, &block)
      end

      def properties
        @properties
      end

      # Creates a composite index for an arbitrary number of database columns. Note that
      # it also is possible to specify single indexes directly for each property.
      #
      # === EXAMPLE WITH COMPOSITE INDEX:
      #   class Person < DataMapper::Base
      #     property :server_id, :integer
      #     property :name, :string
      #
      #     index [:server_id, :name]
      #   end
      #
      # === EXAMPLE WITH COMPOSITE UNIQUE INDEX:
      #   class Person < DataMapper::Base
      #     property :server_id, :integer
      #     property :name, :string
      #
      #     index [:server_id, :name], :unique => true
      #   end
      #
      # === SINGLE INDEX EXAMPLES:
      # * property :name, :index => true
      # * property :name, :index => :unique
      def index(indexes, unique = false)
        if indexes.kind_of?(Array) # if given an index of multiple columns
          database.schema[self].add_composite_index(indexes, unique)
        else
          raise ArgumentError.new("You must supply an array for the composite index")
        end
      end

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

    def database_context
      @database_context || ( @database_context = database )
    end

    def database_context=(value)
      @database_context = value
    end

    def logger
      self.class.logger
    end

    def new_record?
      @new_record.nil? || @new_record
    end

    def lazy_loaded_attributes
      @lazy_loaded_attributes || @lazy_loaded_attributes = Set.new
    end

    def update_attributes(update_hash)
      self.attributes = update_hash
      self.save
    end

    def dirty?(cleared = Set.new)
      return false if cleared.include?(self)
      cleared << self

      result = database_context.table(self).columns.any? do |column|
        if column.type == :object
          Marshal.dump(self.instance_variable_get(column.instance_variable_name)) != original_values[column.name]
        else
          self.instance_variable_get(column.instance_variable_name) != original_values[column.name]
        end
      end

      return true if result

      loaded_associations.any? do |loaded_association|
        loaded_association.dirty?(cleared)
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

    def original_values=(values)
      values.each_pair do |k,v|
        original_values[k] = case v
        	when String, Date, Time then v.dup
                  # when column.type == :object then Marshal.dump(v)
        	else v
        end
      end
    end

    def original_values
      class << self
        attr_reader :original_values
      end

      @original_values = {}
    end

    def loaded_set=(value)
      value << self
      @loaded_set = value
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

    def keys
      self.class.table.keys.map do |column|
        column.type_cast_value(instance_variable_get(column.instance_variable_name))
      end.compact
    end

    def <=>(other)
      keys <=> other.keys
    end

    # Look to ::included for __hash alias
    def hash
      @__hash || @__hash = keys.empty? ? super : keys.hash
    end

    def eql?(other)
      return false unless other.is_a?(self.class) || self.is_a?(other.class)
      comparator = keys.empty? ? :private_attributes : :keys
      send(comparator) == other.send(comparator)
    end

    def ==(other)
      eql?(other)
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
  end
end
