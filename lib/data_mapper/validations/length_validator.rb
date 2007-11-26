module DataMapper
  module Validations
    
    class LengthValidator < GenericValidator
      
      def initialize(field_name, options)
        @field_name = field_name
        @options = options
        
        @min = options[:minimum] || options[:min]
        @max = options[:maximum] || options[:max]
        @equal = options[:is] || options[:equals]
        @range = options[:within] || options[:in]

        @validation_method ||= :range if @range
        @validation_method ||= :min if @min && @max.nil?
        @validation_method ||= :max if @max && @min.nil?
        @validation_method ||= :equals unless @equal.nil?
      end
      
      def call(target)
        field_value = target.instance_variable_get("@#{@field_name}").to_s
        return true if @options[:allow_nil] && field_value.nil?
        
        # HACK seems hacky to do this on every validation, probably should do this elsewhere?
        field = Inflector.humanize(@field_name)
        min = @range ? @range.min : @min
        max = @range ? @range.max : @max
        equal = @equal

        error_message = @options[:message]
        
        case @validation_method
        when :range then
          unless valid = @range.include?(field_value.size)
            error_message = '%s must be between %s and %s characters long'.t(field, min, max)
          end
        when :min then
          unless valid = field_value.size >= min
            error_message = '%s must be more than %s characters long'.t(field, min)
          end
        when :max then
          unless valid = field_value.size <= max
            error_message = '%s must be less than %s characters long'.t(field, max)
          end
        when :equals then
          unless valid = field_value.size == equal
            error_message = '%s must be %s characters long'.t(field, equal)
          end
        end unless error_message
        
        add_error(target, error_message, @field_name) unless valid

        return valid
      end

    end
    
    module ValidatesLengthOf
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        DEFAULT_VALIDATES_LENGTH_OF_OPTIONS = { :on => :save }

        def validates_length_of(field, options = {})
          opts = retrieve_options_from_arguments_for_validators([options], DEFAULT_VALIDATES_LENGTH_OF_OPTIONS)
          validations.context(opts[:context]) << Validations::LengthValidator.new(field, opts)
        end

      end
    end
    
  end  
end