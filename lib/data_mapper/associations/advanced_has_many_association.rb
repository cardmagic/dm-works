module DataMapper
  module Associations
    
    class AdvancedHasManyAssociation
      include Enumerable
      
      def initialize(klass, association_name, options)
        @association_name = association_name.to_sym
        @options = options

        # Define the association instance method (i.e. Project#tasks)
        klass.class_eval <<-EOS
          def #{association_name}
            @#{association_name} || (@#{association_name} = HasManyAssociation.new(self, "#{association_name}", #{options.inspect}))
          end
        EOS
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
          Kernel.const_get(Inflector.classify(association_name))
        end
      end
      
      def foreign_key
        @foreign_key || (@foreign_key = (@options[:foreign_key] || @instance.session.schema[@instance.class].default_foreign_key))
      end

    end
    
    module AdvancedHasMany
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def advanced_has_many(association_name, options = {})
          database.schema[self].associations << AdvancedHasManyAssociation.new(self, association_name, options)
        end
      end
    end
    
  end
end