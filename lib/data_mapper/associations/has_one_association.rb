require 'data_mapper/associations/has_n_association'

module DataMapper
  module Associations
    
    class HasOneAssociation < HasNAssociation
      
      # Define the association instance method (i.e. Project#tasks)
      def define_accessor(klass)        
        klass.class_eval <<-EOS
          def create_#{@association_name}(options)
            #{@association_name}_association.create(options)
          end
          
          def build_#{@association_name}(options)
            #{@association_name}_association.build(options)
          end

          def #{@association_name}
            #{@association_name}_association.instance
          end
          
          def #{@association_name}=(value)
            #{@association_name}_association.set(value)
          end
          
          private
            def #{@association_name}_association
              @#{@association_name}_association || (@#{@association_name}_association = HasOneAssociation::Instance.new(self, #{@association_name.inspect}))
            end
        EOS
      end
      
      class Instance < HasNAssociation::Reference
      
        def instance
          @associated || @associated = begin                    
            if @instance.loaded_set.nil?
              nil
            else
              # Temp variable for the instance variable name.
              setter_method = "#{@association_name}=".to_sym
              instance_variable_name = "@#{association.foreign_key}".to_sym
          
              set = @instance.loaded_set.group_by { |instance| instance.key }
          
              # Fetch the foreign objects for all instances in the current object's loaded-set.
              @instance.session.all(association.constant, association.foreign_key => set.keys).each do |assoc|
                set[assoc.instance_variable_get(instance_variable_name)].first.send(setter_method, assoc)
              end
              
              @associated
            end
            
          end
        end

        def create(options)
          @associated = association.constant.new(options)
          if @associated.save
            @associated.send("#{@associated_class.foreign_key}=", @instance.key)
          end
        end
      
        def build(options)
          @associated = association.constant.new(options)
        end
      
        def set(val)
          @associated = val
        end
            
      end # class Instance
      
    end # class HasOneAssociation
  end # module Associations
end # module DataMapper