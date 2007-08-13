module DataMapper
  module Associations
    
    class AdvancedHasManyAssociation
      
      def initialize(klass, association_name, options)
        @table = database.schema[klass]
        @association_name = association_name.to_sym
        @options = options

        # Define the association instance method (i.e. Project#tasks)
        klass.class_eval <<-EOS
          def #{association_name}
            @#{association_name} || (@#{association_name} = AdvancedHasManyAssociation::Set.new(self, #{association_name.inspect}))
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
        @foreign_key || (@foreign_key = (@options[:foreign_key] || @table.default_foreign_key))
      end
      
      class Set
        
        include Enumerable
        
        def initialize(instance, association_name)
          @instance, @association_name = instance, association_name
        end
        
        def each
          entries.each { |item| yield item }
        end

        def size
          entries.size
        end
        alias length size

        def [](key)
          entries[key]
        end

        def empty?
          entries.empty?
        end
        
        def association
          @association || (@association = @instance.session.schema[@instance.class].association(@association_name))
        end
        
        def entries
          @entries || @entries = begin

            if @instance.loaded_set.nil?
              []
            else
              @instance.session.all(
                association.constant,
                association.foreign_key.to_sym => @instance.loaded_set.map(&:key)
              ).group_by(&association.foreign_key.to_sym).each do |key,instances|
                if instance = @instance.loaded_set.find { |entry| entry.key == key }
                  instance.send(@association_name).set(instances)
                end
              end
              
              @entries              
            end
          end
        end

        def set(results)
          @entries = results
        end

        def inspect
          @entries.inspect
        end
      end

    end
    
  end
end