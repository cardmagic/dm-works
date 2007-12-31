module DataMapper
  
  module Attributes
    
    def self.included(klass)
      klass.const_set('ATTRIBUTES', Set.new) unless klass.const_defined?('ATTRIBUTES')
    end
    
    def attributes
      pairs = {}
      
      self.class::ATTRIBUTES.each do |name|
        getter = if self.class.public_method_defined?(name)
          name
        elsif self.class.public_method_defined?(name.to_s.ensure_ends_with('?'))
          name.to_s.ensure_ends_with('?')
        else
          nil         
        end
        
        if getter
          value = send(getter)
          pairs[name] = value.is_a?(Class) ? value.to_s : value
        end
      end
      
      pairs
    end
    
    # Mass-assign mapped fields.
    def attributes=(values_hash)
      values_hash.each_pair do |k,v|
        setter_name = k.to_s.sub(/\?$/, '').ensure_ends_with('=')
        if self.class.public_method_defined?(setter_name)
          send(setter_name, v)
        end
      end
      
      self
    end
  end
  
end