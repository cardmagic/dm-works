require 'data_mapper/associations/has_n_association'

module DataMapper
  module Associations
    
    class BelongsToAssociation < HasNAssociation

      def define_accessor(klass)        
        klass.class_eval <<-EOS
          
          def create_#{@association_name}(options = {})
            #{@association_name}_association.create(options)
          end
          
          def build_#{@association_name}(options = {})
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
              @#{@association_name} || (@#{@association_name} = DataMapper::Associations::BelongsToAssociation::Instance.new(self, #{@association_name.inspect}))
            end
        EOS
      end
      
      # Reverse the natural order for BelongsToAssociations
      alias constant associated_constant
      def associated_constant
        @constant
      end
      
      def foreign_key_name
        @foreign_key_name || @foreign_key_name = (@options[:foreign_key] || "#{name}_#{key_table.key.name}".to_sym)
      end
      
      def to_sql
        "JOIN #{key_table.to_sql} ON #{foreign_key_column.to_sql(true)} = #{primary_key_column.to_sql(true)}"
      end
      
      class Instance < Associations::Reference
         
        def instance
          @associated || @associated = begin                    
            if @instance.loaded_set.nil?
              nil
            else
              
              # Temp variable for the instance variable name.
              fk = association.foreign_key_column.to_sym
              
              set = @instance.loaded_set.group_by { |instance| instance.send(fk) }

              @instance.session.all(association.constant, association.associated_table.key.to_sym => set.keys).each do |assoc|
                set[assoc.key].each do |primary_instance|
                  primary_instance.send(setter_method, assoc)
                end
              end

              @associated
            end
          end
        end
      
        def create(options)
          @associated = association.associated_constant.create(options)
        end
      
        def build(options)
          @associated = association.associated_constant.new(options)
        end
      
        def setter_method
          "#{@association_name}=".to_sym
        end
        
        def set(val)
          @instance.instance_variable_set(association.foreign_key_column.instance_variable_name, val.key)
          @associated = val
        end
        
        def ensure_foreign_key!
          if @associated
            @instance.instance_variable_set(association.foreign_key.instance_variable_name, @associated.key)
          end
        end
            
      end # class Instance
    end
    
  end
end