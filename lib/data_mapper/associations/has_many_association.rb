require 'data_mapper/associations/has_n_association'
# require 'forwardable'

module DataMapper
  module Associations
    
    class HasManyAssociation < HasNAssociation
      # extend Forwardable
      
      # Define the association instance method (i.e. Project#tasks)
      def define_accessor(klass)
        klass.class_eval <<-EOS
          def #{@association_name}
            @#{@association_name} || (@#{@association_name} = DataMapper::Associations::HasManyAssociation::Set.new(self, #{@association_name.inspect}))
          end
          
          def #{@association_name}=(value)
            #{@association_name}.set(value)
          end
        EOS
      end
      
      class Set < Associations::Reference
        
        include Enumerable
        
        def dirty?
          @items && @items.any? { |item| item != @instance && item.dirty? }
        end
        
        def validate_excluding_association(associated, context)
          @items.blank? || @items.all? { |item| item.validate_excluding_association(associated, context) }
        end
        
        def save
          unless @items.nil? || @items.empty?
            setter_method = "#{@association_name}=".to_sym
            ivar_name = association.foreign_key.instance_variable_name
            @items.each do |item|
              item.instance_variable_set(ivar_name, @instance.key)
              item.save
            end
          end
        end
        
        def each
          items.each { |item| yield item }
        end
        
        def <<(associated_item)
          items << associated_item
          
          # TODO: Optimize!
          fk = association.foreign_key
          foreign_association = association.association_table.associations.find do |mapping|
            mapping.is_a?(BelongsToAssociation) && mapping.foreign_key == fk
          end
          
          associated_item.send("#{foreign_association.name}=", @instance) if foreign_association
          
          return @items
        end

        def size
          items.size
        end
        alias length size

        def [](index)
          items[index]
        end

        def empty?
          items.empty?
        end
        
        def set(items)
          @items = items
        end

        def items
          @items || begin
            if @instance.loaded_set.nil?
              @items = []
            else
              fk = association.foreign_key.to_sym
              
              finder_options = { association.foreign_key.to_sym => @instance.loaded_set.map { |item| item.key } }
              finder_options.merge!(association.options) if association.options.is_a?(Hash)
              
              associated_items = @instance.session.all(
                association.constant,
                finder_options
              ).group_by { |entry| entry.send(fk) }
              
              setter_method = "#{@association_name}=".to_sym
              @instance.loaded_set.each do |entry|
                entry.send(setter_method, associated_items[entry.key])
              end # @instance.loaded_set.each
              
              return @items
            end # if @instance.loaded_set.nil?
          end # begin
        end # def items
        
        def inspect
          @entries.inspect
        end
      end

    end
    
  end
end