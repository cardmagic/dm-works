require File.dirname(__FILE__) + '/column'

module DataMapper
  module Adapters
    module Sql
      module Mappings
    
        class Table
      
          class Association
            def initialize(association_name, constant_name)
              @association_name, @constant_name = association_name, constant_name
            end
            
            def name
              @association_name
            end
            
            def constant
              @constant || @constant = begin
                Object.const_get(@constant_name)
              end
            end
            
          end
            
          attr_reader :klass
      
          def initialize(adapter, setup_klass)
            raise "\"setup_klass\" must not be nil!" if setup_klass.nil?
            @adapter = adapter
            @klass = setup_klass
            @columns = []
            @columns_hash = Hash.new { |h,k| h[k] = @columns.find { |c| c.name == k } }
            @columns_by_column_name = Hash.new { |h,k| h[k.to_s] = @columns.find { |c| c.column_name == k.to_s } }
            @has_many = []
          end
      
          def has_many(association_name, options)
            @has_many << [ Association.new(association_name, Inflector.classify(Inflector.singularize(association_name.to_s))) ]
          end
          
          def has_many_associations
            @has_many
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
            @name || begin
              @name = if @klass.superclass != DataMapper::Base && @klass.superclass != Object
                @adapter[@klass.superclass].name
              else
                Inflector.tableize(@klass.name)
              end.freeze
            end
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