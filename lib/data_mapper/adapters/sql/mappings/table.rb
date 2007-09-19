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
            @columns = []
            @columns_hash = Hash.new { |h,k| h[k] = @columns.find { |c| c.name == k } }
            @columns_by_column_name = Hash.new { |h,k| h[k.to_s] = @columns.find { |c| c.column_name == k.to_s } }
            @associations = AssociationsSet.new
          end
          
          def associations
            @associations
          end
          
          def reflect_columns
            @adapter.reflect_columns(to_sql)
          end
          
          def columns
            key if @key.nil?
            @columns
          end
          
          def exists?
            @adapter.table_exists?(name)
          end
          
          def drop!
            @adapter.delete(@klass, :drop => true) if exists?
          end
          
          def create!
            @adapter.save(database, @klass) unless exists?
          end
      
          def key
            if @key.nil?
              key_column = @columns.find { |c| c.key? }
              @key = if key_column.nil?
                column = add_column(:id, :integer, :key => true)
                @klass.send(:attr_reader, :id) unless @klass.methods.include?(:id)
                column
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
              column = Column.new(@adapter, self, column_name, type, options)
              @columns.send(column_name == :id ? :unshift : :push, column)
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
            @name || @name = if @klass_or_name.kind_of?(String)
              @klass_or_name
            elsif @klass_or_name.kind_of?(Class)
              if @klass_or_name.superclass != DataMapper::Base \
                && @klass_or_name.ancestors.include?(DataMapper::Base)
                @adapter[@klass_or_name.superclass].name
              else
                Inflector.tableize(@klass_or_name.name)
              end
            else
              raise '+klass_or_name+ must be a Class or a string containing the name of a table'
            end.freeze
          end
      
          def name=(value)
            @name = value
          end
      
          def default_foreign_key
            @default_foreign_key || (@default_foreign_key = "#{String::memoized_underscore(Inflector.singularize(name))}_id".freeze)
          end
      
          def to_sql
            @to_sql || (@to_sql = @adapter.quote_table_name(name).freeze)
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
  end
end