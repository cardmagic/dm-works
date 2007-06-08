require 'data_mapper/mappings/column'

module DataMapper
  module Mappings
    
    class Table
      
      attr_reader :klass
      
      def initialize(database, klass)
        unless database.kind_of?(DataMapper::Database) && klass.kind_of?(Class)
          raise "Database and klass are required: #{ { :database => database, :klass => klass }.inspect }"
        end
        
        @database = database
        @klass = klass
        @columns = []
        @columns_hash = Hash.new { |h,k| h[k] = @columns.find { |c| c.name == k } }
        @columns_by_column_name = Hash.new { |h,k| h[k.to_s] = @columns.find { |c| c.column_name == k.to_s } }
      end
      
      def columns
        key if @key.nil?
        @columns
      end
      
      def key
        if @key.nil?
          key_column = @columns.find { |c| c.key? }
          @key = if key_column.nil?
            add_column(:id, :integer, :key => true)
            @klass.send(:attr_reader, :id) unless @klass.methods.include?(:id)
            @columns.last
          else
            key_column
          end
        end
          
        @key
      end
      
      def add_column(column_name, type, options)
        column = @columns.find { |c| c.name == column_name.to_sym }
        
        if column.nil?
          reset_derived_columns!
          column = Column.new(@database, column_name, type, options)
          @columns << column
        end
        
        return column
      end
      
      def [](column_name)
        return key if column_name == :id
        @columns_hash[column_name.kind_of?(Symbol) ? column_name : column_name.to_sym]
      end
      
      def find_by_column_name(column_name)
        @columns_by_column_name[column_name.kind_of?(String) ? column_name : column_name.to_s]
      end
      
      def name
        @name || begin
          @name = if @klass.superclass != DataMapper::Base
            @database[@klass.superclass].name
          else
            Inflector.tableize(@klass.name)
          end.freeze
        end
      end
      
      def name=(value)
        @name = value
      end
      
      def default_foreign_key
        @default_foreign_key || (@default_foreign_key = "#{Inflector.underscore(Inflector.singularize(name))}_id".freeze)
      end
      
      def to_sql
        @to_sql || (@to_sql = @database.quote_table_name(name).freeze)
      end
      
      def inspect
        "#<%s:0x%x @klass=%s, @name=%s, @columns=%s>" % [self.class.name, (object_id * 2), @klass.name, to_sql, @columns.inspect]
      end
      
      private
      def reset_derived_columns!
        @columns_hash.clear
        @columns_by_column_name.clear
        @key = nil
      end
      
    end
    
  end  
end