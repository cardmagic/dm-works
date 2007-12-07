module DataMapper                        
  
  class ForeignKeyNotFoundError < StandardError; end
    
  module Associations
    
    class HasNAssociation
      
      attr_reader :adapter, :table, :options
      
      OPTIONS = [
        :class,
        :class_name,
        :foreign_key
      ]
      
      def initialize(klass, association_name, options)
        @adapter = database.adapter
        @table = adapter.table(klass)
        @association_name = association_name.to_sym
        @options = options || Hash.new
        
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
          elsif associated_class_name.kind_of?(Class)
            associated_class_name
          else
            raise MissingConstantError, associated_class_name
          end
        else            
          Kernel.const_get(Inflector.classify(@association_name))
        end
      end
      
      def foreign_key
        @foreign_key || begin
          @foreign_key = association_table[foreign_key_name]
          raise(ForeignKeyNotFoundError.new(foreign_key_name)) unless @foreign_key
          @foreign_key
        end
      end
      
      def foreign_key_name
        @foreign_key_name || @foreign_key_name = (@options[:foreign_key] || table.default_foreign_key)
      end
      
      def association_table
        @association_table || (@association_table = adapter.table(constant))
      end
      
      def to_sql
        "JOIN #{association_table.to_sql} ON #{foreign_key.to_sql(true)} = #{table.key.to_sql(true)}"
      end
      
      def association_columns
        association_table.columns.reject { |column| column.lazy? }
      end
      
      def finder_options
        @finder_options || @finder_options = @options.reject { |k,v| self.class::OPTIONS.include?(k) }
      end
    end
    
  end
end