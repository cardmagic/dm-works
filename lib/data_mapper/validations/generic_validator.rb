module DataMapper
  module Validations
    
    # All Validators should inherit from the GenericValidator.
    class GenericValidator
    
      # Adds an error message to the target class.
      def add_error(target, message, attribute = :base)
        target.errors.add(attribute, message)
      end
      
      # Call the validator. We use "call" so the operation
      # is BoundMethod and Block compatible.
      # The result should always be TRUE or FALSE.
      def call(target)
        raise 'You must overwrite this method'
      end
      
    end
        
  end
end