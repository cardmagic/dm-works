module DataMapper
  module Validations
    
    class RequiredFieldValidator < GenericValidator

      def initialize(field_name, options={})
        super
        @field_name, @options = field_name, options
      end
      
      def call(target)
        field_value = !target.instance_variable_get("@#{@field_name}").blank?
        return true if field_value
        
        error_message = @options[:message] || "%s must not be blank".t(Inflector.humanize(@field_name))
        add_error(target, error_message , @field_name)
        
        return false
      end
      
    end
    
    module ValidatesPresenceOf
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods

        def validates_presence_of(*fields)
          options = retrieve_options_from_arguments_for_validators(fields)
          fields.each do |field|
            validations.context(options[:context]) << Validations::RequiredFieldValidator.new(field, options)
          end
        end

      end
    end
    
  end  
end
