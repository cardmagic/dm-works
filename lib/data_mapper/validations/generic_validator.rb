module DataMapper
  module Validations
    
    # All Validators should inherit from the GenericValidator.
    class GenericValidator
      
      attr_accessor :_if_clause
      
      def initialize(field, opts = {})
        @_if_clause = opts[:if]
      end
    
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
      
      def execute_validation?(target)
        return true unless self._if_clause
        if Symbol === self._if_clause
          target.send(self._if_clause)
        elsif self._if_clause.respond_to?(:call)
          self._if_clause.call(target)
        else
          true
        end
      end
      
    end
        
  end
end