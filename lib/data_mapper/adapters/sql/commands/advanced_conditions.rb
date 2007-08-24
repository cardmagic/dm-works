module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class AdvancedConditions
      
          def initialize(adapter, loader, conditions_hash)
            @adapter, @loader = adapter, loader
            @conditions = parse_conditions(conditions_hash)
          end
      
          def empty?
            @conditions.empty?
          end
      
          def to_parameterized_sql
            sql = []
            parameters = []
            
            @conditions.each do |condition|
              case condition
              when String then sql << condition
              when Array then
                  sql << condition.shift
                  parameters += condition
              else
                raise "Unable to parse condition: #{condition.inspect}" if condition
              end
                
              if condition.kind_of?(String)
                sql << condition
              elsif condition.kind_of?(Array)
                
              end
            end
            
            parameters.unshift(sql.join(' '))
          end
          
          private
            
            def expression_to_sql(clause, value, collector)
              qualify_columns = @loader.qualify_columns?
              
              if clause.kind_of?(Symbol::Operator)
                if clause.type == :select
                  clause.options[:class] ||= @loader.klass
              
                  clause.options[:select] ||= if clause.value.to_s == @adapter[clause.options[:class]].default_foreign_key
                    @adapter[clause.options[:class]].key.column_name
                  else
                    clause.value
                  end
              
                  sub_select = @adapter.select_statement(clause.options.merge(value))
                  expression_to_sql("#{primary_class_table[clause.value.to_sym].to_sql(qualify_columns)} IN ?", sub_select, collector)
                else                
                  @has_id = true if clause.value == :id
                  op = case clause.type
                    when :gt then '>'
                    when :gte then '>='
                    when :lt then '<'
                    when :lte then '<='
                    when :not then value.nil? ? 'IS NOT' : (value.kind_of?(Array) ? 'NOT IN' : '<>')
                    when :eql then value.nil? ? 'IS' : (value.kind_of?(Array) ? 'IN' : '=')
                    when :like then 'LIKE'
                    when :in then 'IN'
                    else raise ArgumentError.new('Operator type not supported')
                  end
                  expression_to_sql("#{primary_class_table[clause.value.to_sym].to_sql(qualify_columns)} #{op} ?", value, collector)
                end
              else
                @has_id = true if clause == :id
                case value
                when Array then
                  expression_to_sql("#{primary_class_table[clause.to_sym].to_sql(qualify_columns)} IN ?", value, collector)
                when LoadCommand then
                  expression_to_sql("#{primary_class_table[clause.to_sym].to_sql(qualify_columns)} IN ?", value, collector)
                else
                  collector << ["#{primary_class_table[clause.to_sym].to_sql(qualify_columns)} = ?", value]
                end
              end
            end
            
            def parse_conditions(conditions_hash)
              collection = []
              
              case x = conditions_hash.delete(:conditions)
              when Hash then
                x.each_pair do |key,value|
                  expression_to_sql(key, value, collection)
                end
              else
                raise "Unable to parse conditions: #{x.inspect}" if x
              end
              
              conditions_hash.each_pair do |key,value|
                expression_to_sql(key, value, collection)
              end
              
              collection              
            end
            
            def primary_class_table
              @primary_class_table || (@primary_class_table = @loader.send(:primary_class_table))
            end
        end
    
      end
    end
  end
end