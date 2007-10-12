module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class Conditions
      
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
            end
            
            parameters.unshift("(#{sql.join(') AND (')})")
          end
          
          private
            
            def expression_to_sql(clause, value, collector)
              qualify_columns = @loader.qualify_columns?
              
              case clause
              when Symbol::Operator then
                operator = case clause.type
                when :gt then '>'
                when :gte then '>='
                when :lt then '<'
                when :lte then '<='
                when :not then inequality_operator(value)
                when :eql then equality_operator(value)
                when :like then equality_operator(value, 'LIKE')
                when :in then equality_operator(value)
                else raise ArgumentError.new('Operator type not supported')
                end
                collector << ["#{primary_class_table[clause].to_sql(qualify_columns)} #{operator} ?", value]
              when Symbol then
                collector << ["#{primary_class_table[clause].to_sql(qualify_columns)} #{equality_operator(value)} ?", value]
              when String then
                collector << [clause, value]
              when Mappings::Column then
                collector << ["#{clause.to_sql(qualify_columns)} #{equality_operator(value)} ?", value]
              else raise "CAN HAS CRASH? #{clause.inspect}"
              end
              
            end
            
            def equality_operator(value, default = '=')
              case value
              when NilClass then 'IS'
              when Array then 'IN'
              else default
              end
            end
            
            def inequality_operator(value, default = '<>')
              case value
              when NilClass then 'IS NOT'
              when Array then 'NOT IN'
              else default
              end
            end
            
            def parse_conditions(conditions_hash)
              collection = []
              
              case x = conditions_hash.delete(:conditions)
              when Array then
                clause = x.shift
                expression_to_sql(clause, x, collection)
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