require 'data_mapper/associations/has_n_association'

module DataMapper
  module Associations
    
    class HasManyAssociation < HasNAssociation
      
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

        def build(options)
          item = association.constant.new(options)
          self << item          
          item
        end

        def create(options)
          item = build(options)
          item.save
          item
        end
        
        def set(items)
          @items = items
        end
        
        def method_missing(symbol, *args, &block)
          if items.respond_to?(symbol)
            items.send(symbol, *args, &block)
          elsif association.association_table.associations.any? { |assoc| assoc.name == symbol }
            results = []
            each do |item|
              unless (val = item.send(symbol)).blank?
                results << (val.is_a?(Enumerable) ? val.entries : val)
              end
            end
            results.flatten
          else
            super
          end
        end
        
        def respond_to?(symbol)
          items.respond_to?(symbol) || super
        end

        def items
          @items || begin
            if @instance.loaded_set.nil?
              @items = []
            else
              fk = association.foreign_key.to_sym
              
              finder_options = { association.foreign_key.to_sym => @instance.loaded_set.map { |item| item.key } }
              finder_options.merge!(association.finder_options)
              
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
          entries.inspect
        end
      end

    end
    
  end
end
