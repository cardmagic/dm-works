require 'data_mapper/loaded_set'
require 'data_mapper/identity_map'

module DataMapper
  
  class Session
    
    FIND_OPTIONS = [
        :select, :limit, :class, :include, :reload, :conditions, :order
      ]
      
    class MaterializationError < StandardError
    end
    
    def initialize(database)
      @database = database
    end
    
    def identity_map
      @identity_map || ( @identity_map = IdentityMap.new )
    end
    
    def find(klass, type_or_id, options = {}, &b)
      options.merge! b.to_hash if block_given?
      
      results = case type_or_id
        when :first then
          first(@database.select_statement(options.merge(:class => klass, :limit => 1)))
        when :all then
          all(@database.select_statement(options.merge(:class => klass)))
        else
          first(@database.select_statement(options.merge(:class => klass, :id => type_or_id)))
      end
      
      case results
        when Array then results.each { |instance| instance.session = self }
        when Base then results.session = self
      end
      return results
    end
    
    def first(options)
      if options.has_id? && !options.reload?
        instance = identity_map.get(options.klass, options.instance_id)
        return instance unless instance.nil?
      end
      
      reader = @database.query(options)
      instance = reader.eof? ? nil : load(options, reader.next)
      reader.close
      return instance
    rescue DatabaseError => de
      de.options = options
      raise de
    end
    
    def all(options)
      set = LoadedSet.new(@database)
      reader = @database.query(options)
      instances = reader.map do |hash|
        load(options, hash, set)
      end
      reader.close
      return instances
    rescue => error
      @database.log.error(error)
      raise error
    end
    
    def load(options, hash, set = LoadedSet.new(@database))
            
      instance_class = unless hash['type'].nil?
        Kernel::const_get(hash['type'])
      else
        options.klass
      end
      
      mapping = @database[instance_class]
      
      instance_id = mapping.key.type_cast_value(hash['id'])      
      instance = identity_map.get(instance_class, instance_id)
      
      if instance.nil? || options.reload?
        instance ||= instance_class.new        
        instance.class.callbacks.execute(:before_materialize, instance)
        
        instance.instance_variable_set(:@new_record, false)
        hash.each_pair do |name_as_string,raw_value|
          name = name_as_string.to_sym
          if column = mapping.find_by_column_name(name)
            value = column.type_cast_value(raw_value)
            instance.instance_variable_set(column.instance_variable_name, value)
          else
            instance.instance_variable_set("@#{name}", value)
          end
          instance.original_hashes[name] = value.hash
        end

        instance.class.callbacks.execute(:after_materialize, instance)
        
        identity_map.set(instance)
      end
      
      instance.instance_variable_set(:@loaded_set, set)
      set.instances << instance
      return instance
    end
    
    def save(instance)
      return false unless instance.dirty?
      instance.class.callbacks.execute(:before_save, instance)
      result = instance.new_record? ? insert(instance) : update(instance)
      instance.session = self
      instance.class.callbacks.execute(:after_save, instance)
      result.success?
    end
    
    def insert(instance, inserted_id = nil)
      instance.class.callbacks.execute(:before_create, instance)
      result = @database.execute(@database.insert_statement(instance))
      
      if result.success?
        instance.instance_variable_set(:@new_record, false)
        instance.instance_variable_set(:@id, inserted_id || result.last_inserted_id)
        calculate_original_hashes(instance)
        identity_map.set(instance)
        instance.class.callbacks.execute(:after_create, instance)
      end
      
      return result
    rescue => error
      @database.log.error(error)
      raise error
    end
    
    def update(instance)
      instance.class.callbacks.execute(:before_update, instance)
      result = @database.execute(@database.update_statement(instance))
      calculate_original_hashes(instance)
      instance.class.callbacks.execute(:after_update, instance)
      return result
    rescue => error
      @database.log.error(error)
      raise error
    end
    
    def destroy(instance)
      instance.class.callbacks.execute(:before_destroy, instance)
      result = @database.execute(@database.delete_statement(instance))
      if result.success?
        instance.instance_variable_set(:@new_record, true)
        instance.original_hashes.clear
        instance.class.callbacks.execute(:after_destroy, instance)
      end
      return result.success?
    rescue => error
      @database.log.error(error)
      raise error
    end
    
    def delete_all(klass)
      @database.execute(@database.delete_statement(klass))
    end
    
    def truncate(klass)
      @database.connection do |db|
        db.execute(@database.truncate_table_statement(klass))
      end
    end
    
    def create_table(klass)
      @database.connection do |db|
        db.execute(@database.create_table_statement(klass))
      end unless table_exists?(klass)
    end
    
    def drop_table(klass)
      @database.connection do |db|
        db.execute(@database.drop_table_statement(klass))
      end if table_exists?(klass)
    end
    
    def table_exists?(klass)
      reader = @database.connection do |db|
        db.query(@database.table_exists_statement(klass))
      end
      result = !reader.eof?
      reader.close
      result
    end
    
    def query(*args)
      sql = args.shift
      
      unless args.empty?
        sql.gsub!(/\?/) do |x|
          @database.quote_value(args.shift)
        end
      end

      reader = @database.connection do |db|
        db.query(sql)
      end
      
      columns = reader.columns.keys
      klass = Struct.new(*columns.map { |c| c.to_sym })
      
      rows = reader.map do |row|
        klass.new(*columns.map { |c| row[c] })
      end
      
      reader.close
      return rows
    end
    
    def schema
      @database.schema
    end
    
    def log
      @database.log
    end
    
    private
    
    # Make sure this uses the factory changes later...
    def type_cast_value(klass, name, raw_value)
      @database[klass][name].type_cast_value(raw_value)
    end
    
    # Calculates the original hashes for each value
    # in an instance's set of attributes, and adds
    # them to the original_hashes hash.
    def calculate_original_hashes(instance)
      instance.attributes.each_pair do |name, value|
        instance.original_hashes[name] = value.hash
      end
    end
  end
end