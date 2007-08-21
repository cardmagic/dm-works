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
        
        def each
          items.each { |item| yield item }
        end

        def size
          items.size
        end
        alias length size

        def [](key)
          items[key]
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
              
              associated_items = @instance.session.all(
                association.constant,
                association.foreign_key.to_sym => @instance.loaded_set.map(&:key)
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