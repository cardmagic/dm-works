require 'data_mapper/identity_map'

module DataMapper
  
  class Context
      
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
      
      # Account for undesired behaviour in MySQL that returns the
      # last inserted row when the WHERE clause contains a "#{primary_key} IS NULL".
      return nil if options.has_key?(:id) && options[:id] == nil
      
      @adapter.load(self, klass, options).first
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
      @adapter.delete(self, instance)
    end
    
    def delete_all(klass)
      @adapter.delete(self, klass)
    end
    
    def truncate(klass)
      @adapter.truncate(self, klass)
    end
    
    def create_table(klass)
      @adapter.create_table(klass)
    end
    
    def drop_table(klass)
      @adapter.drop(self, klass)
    end
    
    def table_exists?(klass)
      @adapter.table_exists?(klass)
    end
    
    def column_exists_for_table?(klass, column_name)
      @adapter.column_exists_for_table?(klass, column_name)
    end
    
    def execute(*args)
      @adapter.execute(*args)
    end
    
    def query(*args)      
      @adapter.query(*args)
    end
    
    def schema
      @adapter.schema
    end
    
    def table(klass)
      @adapter.table(klass)
    end
    
    def logger
      @logger || @logger = @adapter.logger
    end

  end
end