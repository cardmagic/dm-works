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
      
      def to_disassociate_sql
        "UPDATE #{associated_table.to_sql} SET #{foreign_key_column.to_sql} = NULL WHERE #{foreign_key_column.to_sql} = ?"
      end
      
      def instance_variable_name
        class << self
          attr_reader :instance_variable_name
        end
        
        @instance_variable_name = "@#{@association_name}"
      end
      
      class Set < Associations::Reference
        
        include Enumerable
        
        # Returns true if the association has zero items
        def nil?
          @items.empty?
        end
        
        def dirty?
          @items && @items.any? { |item| item.dirty? }
        end
        
        def validate_recursively(event, cleared)
          @items.blank? || @items.all? { |item| cleared.include?(item) || item.validate_recursively(event, cleared) }
        end
        
        def save_without_validation(database_context)
          
          adapter = @instance.database_context.adapter
          
          adapter.connection do |db|
            command = db.create_command(association.to_disassociate_sql)
            command.execute_non_query(@instance.key)
          end
          
          unless @items.nil? || @items.empty?
            
            
            setter_method = "#{@association_name}=".to_sym
            ivar_name = association.foreign_key_column.instance_variable_name
            @items.each do |item|
              item.instance_variable_set(ivar_name, @instance.key)
              @instance.database_context.adapter.save_without_validation(database_context, item)
            end
          end
        end
        
        def each
          items.each { |item| yield item }
        end
        
        def <<(associated_item)
          (@items || @items = []) << associated_item
          
          # TODO: Optimize!
          fk = association.foreign_key_column
          foreign_association = association.associated_table.associations.find do |mapping|
            mapping.is_a?(BelongsToAssociation) && mapping.foreign_key_column == fk
          end
          
          associated_item.send("#{foreign_association.name}=", @instance) if foreign_association
          
          return @items
        end

        def build(options)
          item = association.associated_constant.new(options)
          self << item
          item
        end

        def create(options)
          item = build(options)
          item.save
          item
        end
        
        def set(value)
          values = value.is_a?(Enumerable) ? value : [value]
          @items = []
          values.each do |item|
            self << item
          end
        end
        
        def method_missing(symbol, *args, &block)
          if items.respond_to?(symbol)
            items.send(symbol, *args, &block)
          elsif association.associated_table.associations.any? { |assoc| assoc.name == symbol }
            results = []
            each do |item|
              unless (val = item.send(symbol)).blank?
                results << (val.is_a?(Enumerable) ? val.entries : val)
              end
            end
            results.flatten
          elsif items.size == 1 && items.first.respond_to?(symbol)
            items.first.send(symbol, *args, &block)
          else
            super
          end
        end
        
        def respond_to?(symbol)
          items.respond_to?(symbol) || super
        end
        
        def reload!
          @items = nil
        end

        def items
          @items || begin
            if @instance.loaded_set.nil?
              @items = []
            else              
              associated_items = fetch_sets
              
              # This is where @items is set, by calling association=,
              # which in turn calls HasManyAssociation::Set#set.
              association_ivar_name = association.instance_variable_name
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
        
        def ==(other)
          (items.size == 1 ? items.first : items) == other
        end
        
        private
        def fetch_sets
          finder_options = { association.foreign_key_column.to_sym => @instance.loaded_set.map { |item| item.key } }
          finder_options.merge!(association.finder_options)
          
          foreign_key_ivar_name = association.foreign_key_column.instance_variable_name
          
          @instance.database_context.all(
            association.associated_constant,
            finder_options
          ).group_by { |entry| entry.instance_variable_get(foreign_key_ivar_name) }
        end
        
      end

    end
    
  end
end
