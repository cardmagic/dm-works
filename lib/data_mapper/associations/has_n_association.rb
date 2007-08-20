module DataMapper
  module Associations
    
    class HasNAssociation
      
      attr_reader :adapter, :table
      
      def initialize(klass, association_name, options)
        @adapter = database.adapter
        @table = adapter[klass]
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
        @foreign_key || @foreign_key = begin
          association_table[@options[:foreign_key] || table.default_foreign_key]
        end
      end
      
      def association_table
        @association_table || (@association_table = adapter[constant])
      end
      
      def to_sql
        "JOIN #{association_table.to_sql} ON #{foreign_key.to_sql(true)} = #{table.key.to_sql(true)}"
      end
      
      def association_columns
        association_table.columns.reject { |column| column.lazy? }
      end
    end
    
  end
end