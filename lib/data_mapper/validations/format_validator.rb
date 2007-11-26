require File.dirname(__FILE__) + '/formats/email'

module DataMapper
  module Validations
    
    class FormatValidator < GenericValidator
      
      FORMATS = {}
      
      # Seems to me that all this email garbage belongs somewhere else...  Where's the best
      # place to stick it?
      include DataMapper::Validations::Helpers::Email::RFC2822
      
      def initialize(field_name, options = {}, &b)
        @field_name, @options = field_name, options
      end

      def call(target)
        field_value = target.instance_variable_get("@#{@field_name}")
        return true if @options[:allow_nil] && field_value.nil?
        
        validation = (@options[:as] || @options[:with])
        error_message = nil
        
        # Figure out what to use as the actual validator.  If a symbol is passed to :as, look up
        # the canned validation in FORMATS.
        validator = if validation.is_a? Symbol
          if FORMATS[validation].is_a? Array
            error_message = FORMATS[validation][1]
            FORMATS[validation][0]
          else
            FORMATS[validation] || validation
          end
        else
          validation
        end
        
        valid = case validator
        when Proc then validator.call(field_value)
        when Regexp then validator =~ field_value
        else raise UnknownValidationFormat, "Can't determine how to validate #{target.class}##{@field_name} with #{validator.inspect}"
        end 
        
        unless valid
          field = Inflector.humanize(@field_name)
          value = field_value
          
          error_message = @options[:message] || error_message || '%s is invalid'.t(field)
          error_message = error_message.call(field, value) if Proc === error_message
          
          add_error(target, error_message , @field_name)
        end
        
        return valid
      end
      
      class UnknownValidationFormat < StandardError
      end
      
    end
    
    module ValidatesFormatOf
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        # No bueno?
        DEFAULT_OPTIONS = { :on => :save }
        
        def validates_format_of(field, options = {})
          opts = retrieve_options_from_arguments_for_validators([options], DEFAULT_OPTIONS)
          validations.context(opts[:context]) << Validations::FormatValidator.new(field, opts)
        end

      end
    end
    
  end  
end
