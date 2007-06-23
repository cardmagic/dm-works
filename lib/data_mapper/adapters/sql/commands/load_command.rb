require File.dirname(__FILE__) + '/conditions'
require 'inline'

module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class LoadCommand
      
          attr_reader :klass, :order, :limit, :instance_id, :conditions, :options
          
          def initialize(adapter, session, klass, options)
            @adapter, @session, @klass, @options = adapter, session, klass, options
            
            @order = @options[:order]
            @limit = @options[:limit]
            @reload = @options[:reload]
            @instance_id = @options[:id]
            @conditions = Conditions.new(@adapter, self)
          end
          
          def reload?
            @reload
          end

          def escape(conditions)
            @adapter.escape(conditions)
          end
      
          def inspect
            @options.inspect
          end
      
          def include?(association_name)
            return false if includes.empty?
            includes.include?(association_name)
          end
      
          def includes
            @includes || @includes = begin
              list = @options[:include] || []
              list.kind_of?(Array) ? list : [list]
              list
            end
          end
      
          def select
            @select_columns || @select_columns = begin
              select_columns = @options[:select]
              unless select_columns.nil?
                select_columns = select_columns.kind_of?(Array) ? select_columns : [select_columns]
                select_columns.map { |column| @adapter.quote_column_name(column.to_s) }
              else
                @options[:select] = @adapter[klass].columns.select do |column|
                  include?(column.name) || !column.lazy?
                end.map { |column| column.to_sql }
              end
            end
          end
      
          def table_name
            @table_name || @table_name = if @options.has_key?(:table)
              @adapter.quote_table_name(@options[:table])
            else
              @adapter[klass].to_sql
            end
          end
          
          def to_sql
            return @options[:sql] if @options.has_key?(:sql)
            
            sql = 'SELECT ' << select.join(', ') << ' FROM ' << table_name
        
            where = []
        
            where += conditions.to_a unless conditions.empty?
        
            unless where.empty?
              sql << ' WHERE (' << where.join(') AND (') << ')'
            end
        
            unless order.nil?
              sql << ' ORDER BY ' << order.to_s
            end
        
            unless limit.nil?
              sql << ' LIMIT ' << limit.to_s
            end
        
            return sql
          end
          
          def call
            
            if @klass == Struct
              return load_structs(execute(to_sql))
            end
            
            if instance_id && !reload?
              if instance_id.kind_of?(Array)
                instances = instance_id.map do |id|
                  @session.identity_map.get(klass, id)
                end.compact
                
                return instances if instances.size == instance_id.size
              else
                instance = @session.identity_map.get(klass, instance_id)
                return instance unless instance.nil?
              end
            end
            
            reader = execute(to_sql)
            
            results = if eof?(reader)
              nil
            elsif limit == 1 || ( instance_id && !instance_id.kind_of?(Array) )
              fetch_one(reader)
            else
              fetch_all(reader)
            end
            
            close_reader(reader)
            
            return results
          end

          def load(hash, set = [])

            instance_class = unless hash['type'].nil?
              Kernel::const_get(hash['type'])
            else
              klass
            end

            mapping = @adapter[instance_class]

            instance_id = mapping.key.type_cast_value(hash['id'])   
            instance = @session.identity_map.get(instance_class, instance_id)

            if instance.nil? || reload?
              instance ||= instance_class.new
              instance.class.callbacks.execute(:before_materialize, instance)

              instance.instance_variable_set(:@new_record, false)
              hash.each_pair do |name_as_string,raw_value|
                name = name_as_string.to_sym
                if column = mapping.find_by_column_name(name)
                  value = column.type_cast_value(raw_value)
                  instance.instance_variable_set(column.instance_variable_name, value)
                else
                  instance.instance_variable_set("@#{name}", value)
                end
                instance.original_hashes[name] = value.hash
              end
              
              instance.instance_variable_set(:@__key, instance_id)
              
              instance.class.callbacks.execute(:after_materialize, instance)

              @session.identity_map.set(instance)
            end

            instance.instance_variable_set(:@loaded_set, set)
            instance.session = @session
            set << instance
            return instance
          end
      
        end
          
        protected
        def count_rows(reader)
          raise NotImplementedError.new
        end
        
        def close_reader(reader)
          raise NotImplementedError.new
        end
        
        def execute(sql)
          raise NotImplementedError.new
        end
        
        def fetch_one(reader)
          raise NotImplementedError.new
        end
        
        def fetch_all(reader)
          raise NotImplementedError.new
        end
        
        def load_structs(reader)
          raise NotImplementedError.new
        end
    
      end
    end
  end
end