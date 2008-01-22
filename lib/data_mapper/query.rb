module DataMapper
  
  class Query
    
    OPTIONS = [
      :select, :offset, :limit, :include, :shallow_include, :reload, :conditions, :order, :intercept_load
    ]
    
    def initialize(adapter, klass, options = {})
      @adapter, @klass = adapter, klass
      @from = @adapter.table(@klass)
      @columns = @from.non_lazy_columns
      @parameters = []
      
      @limit =          options.fetch(:limit, nil)
      @offset =         options.fetch(:offset, nil)
      @include =        options.fetch(:include, []).to_a
      @reload =         options.fetch(:reload, false)
      @conditions =     options.fetch(:conditions, [])
      @order =          options.fetch(:order, nil)
      @intercept_load = options.fetch(:intercept_load, nil)
      
      options.each_pair do |k,v|
        unless OPTIONS.include?(k)
          append_condition(k, v)
        end
      end
      
      if @from.paranoid?
        @conditions << "#{@from.paranoid_column.to_sql(qualify?)} IS NULL OR #{@from.paranoid_column.to_sql(qualify?)} > #{@adapter.class::SYNTAX[:now]}"
      end
    end
    
    def to_sql
      <<-EOS.compress_lines
        SELECT #{columns.map { |column| column.to_sql(qualify?) }.join(', ')}
        FROM #{from.to_sql}
        WHERE (#{conditions.join(") AND (")})
      EOS
    end
    
    def parameters
      @parameters
    end
    
    private
    
    def conditions
      @conditions
    end
    
    def qualify?
      false
    end
    
    def from
      @from
    end
    
    def columns
      @columns
    end
    
    def append_condition(clause, value)
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
          @conditions << "#{from[clause].to_sql(qualify?)} #{operator} ?"
          @parameters << value
        when Symbol then
          @conditions << "#{from[clause].to_sql(qualify?)} #{equality_operator(value)} ?"
          @parameters << value
        when String then
          @conditions << clause
          @parameters << [*value]
        when Mappings::Column then
          @conditions << "#{clause.to_sql(qualify?)} #{equality_operator(value)} ?"
          @parameters << value
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
    
    
  end # class Query
end # module DataMapper