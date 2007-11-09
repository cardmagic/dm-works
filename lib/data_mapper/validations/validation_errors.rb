module DataMapper
  
  class ValidationErrors
  
    def initialize
      @errors = Hash.new { |h,k| h[k.to_sym] = [] }
    end
    
    # Clear existing validation errors.
    def clear!
      @errors.clear
    end
    
    # Add a validation error. Use the attribute :general if
    # the error doesn't apply to a specific attribute.
    def add(attribute, message)
      @errors[attribute] << message
    end
    
    # Collect all errors into a single list.
    def full_messages
      @errors.inject([]) do |list,pair|
        list += pair.last
      end
    end
    
    # Return validation errors for a particular attribute.
    def on(attribute)
      @errors[attribute].empty? ? nil : @errors[attribute]
    end
    
    def each
      @errors.map.each do |k,v|
        yield(v)
      end
    end
    
    def method_missing(meth, *args, &block)
      @errors.send(meth, *args, &block)
    end
   
  end
  
end
