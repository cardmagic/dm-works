require 'data_mapper/identity_map'

module DataMapper
  
  class Session
      
    class MaterializationError < StandardError
    end
    
    attr_reader :adapter
    
    def initialize(adapter)
      @adapter = adapter
    end
    
    def identity_map
      @identity_map || ( @identity_map = IdentityMap.new )
    end
    
    def first(klass, *args)
      id = nil
      options = nil
      
      if args.empty? # No id, no options
        options = { :limit => 1 }
      elsif args.size == 2 && args.last.kind_of?(Hash) # id AND options
        options = args.last.merge(:id => args.first)
      elsif args.size == 1 # id OR options
        if args.first.kind_of?(Hash)
          options = args.first.merge(:limit => 1) # no id, add limit
        else
          options = { :id => args.first } # no options, set id
        end
      else
        raise ArgumentError.new('Session#first takes a class, and optional type_or_id and/or options arguments')
      end
      
      options.merge!(b.to_hash) if block_given?
      
      @adapter.load(self, klass, options)
    end
    
    def all(klass, options = {})
      @adapter.load(self, klass, options)
    end
    
    def count(klass, options = {})
      @adapter.count(klass, options)
    end
    
    def save(instance)
      @adapter.save(self, instance)
    end
    
    def destroy(instance)
      @adapter.delete(instance, :session => self)
    end
    
    def delete_all(klass)
      @adapter.delete(klass, :session => self)
    end
    
    def truncate(klass)
      @adapter.delete(klass, :truncate => true, :session => self)
    end
    
    def create_table(klass)
      @adapter[klass].create!
    end
    
    def drop_table(klass)
      @adapter[klass].drop!
    end
    
    def table_exists?(klass)
      @adapter[klass].exists?
    end
    
    def query(*args)      
      @adapter.query(*args)
    end
    
    def schema
      @adapter.schema
    end
    
    def table(klass)
      @adapter.schema[klass]
    end
    
    def log
      @adapter.log
    end

  end
end