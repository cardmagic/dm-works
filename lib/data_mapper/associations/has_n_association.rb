module DataMapper
  module Associations
    
    class HasNAssociation
      
      def initialize(klass, association_name, options)
        @table = database.schema[klass]
        @association_name = association_name.to_sym
        @options = options
        
        define_accessor(klass)
      end
      
      def name
        @association_name
      end

      def constant
        @associated_class || @associated_class = if @options.has_key?(:class) || @options.has_key?(:class_name)
          associated_class_name = (@options[:class] || @options[:class_name])
          if associated_class_name.kind_of?(String)
            Kernel.const_get(Inflector.classify(associated_class_name))
          else
            associated_class_name
          end
        else            
          Kernel.const_get(Inflector.classify(@association_name))
        end
      end
      
      def foreign_key
        @foreign_key || (@foreign_key = (@options[:foreign_key] || @table.default_foreign_key))
      end
      
      class Reference
        
        def initialize(instance, association_name)
          @instance, @association_name = instance, association_name
        end
        
        def association
          @association || (@association = @instance.session.schema[@instance.class].association(@association_name))
        end
        
      end
    end
    
  end
end