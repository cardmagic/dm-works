require 'data_mapper/support/weak_hash'

module DataMapper
  class IdentityMap
    
    def initialize
      # WeakHash is much more expensive, and not necessary if the IdentityMap is tied to Session instead of Database.
      # @cache = Hash.new { |h,k| h[k] = Support::WeakHash.new }
      @cache = Hash.new { |h,k| h[k] = Hash.new }
    end

    def get(klass, key)
      @cache[klass][key]
    end

    def set(instance)
      instance_key = instance.key
      raise "Can't store an instance with a nil key in the IdentityMap" if instance_key.nil?
        
      @cache[instance.class][instance_key] = instance
    end
    
    def delete(instance)
      # @cache[instance.class].delete(instance.key)
    end
    
    def clear!(klass)
      @cache.delete(klass)
    end
    
  end
end