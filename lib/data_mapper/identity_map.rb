require 'data_mapper/support/weak_hash'

module DataMapper
  class IdentityMap
    
    def initialize
      @cache = Hash.new { |h,k| h[k] = Support::WeakHash.new }
    end

    def get(klass, key)
      @cache[klass][key]
    end

    def set(instance)
      raise "Can't store an instance with a nil key in the IdentityMap" if instance.key == nil
        
      @cache[instance.class][instance.key] = instance
    end
    
    def delete(instance)
      # @cache[instance.class].delete(instance.key)
    end
    
    def clear!(klass)
      @cache.delete(klass)
    end
    
  end
end