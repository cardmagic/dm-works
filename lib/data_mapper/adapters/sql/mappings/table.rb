require File.dirname(__FILE__) + '/column'
require File.dirname(__FILE__) + '/associations_set'

module DataMapper
  module Adapters
    module Sql
      module Mappings
    
        class Table
      
          attr_reader :klass, :name
      
          def initialize(adapter, klass_or_name)
            raise "\"klass_or_name\" must not be nil!" if klass_or_name.nil?
            
            @klass = klass_or_name.kind_of?(String) ? nil : klass_or_name
            @klass_or_name = klass_or_name
            
            @adapter = adapter
            @columns = SortedSet.new
            @columns_hash = Hash.new { |h,k| h[k] = columns.find { |c| c.name == k } }
            
            @associations = AssociationsSet.new
            
            @multi_class = false
            
            if @klass && @klass.ancestors.include?(DataMapper::Base) && @klass.superclass != DataMapper::Base
              @adapter.table(@klass.superclass).columns.each do |column|
                self.add_column(column.name, column.type, column.options)
              end
            end
          end
          
          def schema
            @schema || @schema = @adapter.schema
          end
          
          def multi_class?
            @multi_class
          end
          
          def associations
            @associations
          end
          
          def reflect_columns
            @adapter.reflect_columns(self)
          end
          
          def columns
            key if @key.nil?
            @columns
          end
          
          def exists?
            @adapter.table_exists?(name)
          end
          
          def drop!
            @adapter.drop(database, self)
          end
          
          def create!(force = false)
            unless exists? || force
              drop! if force
              @adapter.create_table(self)
            end
          end
      
          def key
            @key || begin
              @key = @columns.find { |column| column.key? }
              
              if @key.nil?
                @key = add_column(:id, :integer, :key => true, :ordinal => -1)
                @klass.send(:attr_reader, :id) unless @klass.methods.include?(:id)
              end
              
              @key
            end
          end
      
          def add_column(column_name, type, options)

            column_ordinal = if options.is_a?(Hash) && options.has_key?(:ordinal)
              options.delete(:ordinal)
            else
              @columns.size
            end
            
            column = @adapter.class::Mappings::Column.new(@adapter, self, column_name, type, column_ordinal, options)
            @columns << column
            
            @multi_class = true if column_name == :type
        
            return column
          end
      
          def [](column_name)
            @columns_hash[column_name.to_sym]
          end
      
          def name
            @name || @name = if @klass_or_name.kind_of?(String)
              @klass_or_name
            elsif @klass_or_name.kind_of?(Class)
              if @klass_or_name.superclass != DataMapper::Base \
                && @klass_or_name.ancestors.include?(DataMapper::Base)
                @adapter.table(@klass_or_name.superclass).name
              else
                Inflector.tableize(@klass_or_name.name)
              end
            else
              raise "+klass_or_name+ (#{@klass_or_name.inspect}) must be a Class or a string containing the name of a table"
            end.freeze
          end
      
          def name=(value)
            @name = value
          end
      
          def default_foreign_key
            @default_foreign_key || (@default_foreign_key = "#{Inflector.underscore(Inflector.singularize(name))}_id".freeze)
          end
      
          def to_sql
            @to_sql || @to_sql = quote_table.freeze
          end
          
          def to_s
            name.to_s
          end
          
          def to_create_table_sql
            @to_create_table_sql || @to_create_table_sql = begin
              "CREATE TABLE #{to_sql} (#{columns.map { |c| c.to_long_form }.join(', ')})"
            end
          end
          
          def to_exists_sql
            @to_exists_sql || @to_exists_sql = <<-EOS.compress_lines
              SELECT TABLE_NAME
              FROM INFORMATION_SCHEMA.TABLES
              WHERE TABLE_NAME = ?
                AND TABLE_SCHEMA = ?
            EOS
          end
          
          def to_column_exists_sql
            @to_column_exists_sql || @to_column_exists_sql = <<-EOS.compress_lines
              SELECT COLUMN_NAME
              FROM INFORMATION_SCHEMA.COLUMNS
              WHERE TABLE_NAME = ?
              AND COLUMN_NAME = ?
              AND TABLE_SCHEMA = ?
            EOS
          end          
          
          def quote_table
            @adapter.quote_table_name(name)
          end
      
          def inspect
            "#<%s:0x%x @klass=%s, @name=%s, @columns=%s>" % [
              self.class.name,
              (object_id * 2),
              klass.inspect,
              to_sql,
              @columns.inspect
            ]
          end
      
        end
    
      end
    end
  end
end