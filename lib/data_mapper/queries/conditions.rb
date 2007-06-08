module DataMapper
  module Queries
    
    class Conditions
      
      def initialize(database, options)
        @database, @options = database, options
        @has_id = false
      end
      
      class NormalizationError < StandardError
        
        attr_reader :inner_error
        
        def initialize(clause, inner_error = nil)
          @clause = clause
          @inner_error = inner_error
          
          message = "Failed to normalize clause: #{clause.inspect}"
          message << ", Error: #{inner_error.inspect}" unless inner_error.nil?
          
          super(message)
        end
        
      end
      
      def normalize(clause, collector)
        case clause
          when Hash then
            clause.each_pair do |k,v|
              if k.kind_of?(Symbol::Operator)
                if k.type == :select
                  k.options[:class] ||= @options[:class]
                  
                  k.options[:select] ||= if k.value.to_s == @database[k.options[:class]].default_foreign_key
                    @database[k.options[:class]].key.column_name
                  else
                    k.value
                  end
                  
                  sub_select = @database.select_statement(k.options.merge(v))
                  normalize(["#{@database[@options[:class]][k.value.to_sym].to_sql} IN ?", sub_select], collector)
                else                
                  @has_id = true if k.value == :id
                  op = case k.type
                    when :gt then '>'
                    when :gte then '>='
                    when :lt then '<'
                    when :lte then '<='
                    when :not then v.nil? ? 'IS NOT' : (v.kind_of?(Array) ? 'NOT IN' : '<>')
                    when :eql then v.nil? ? 'IS' : (v.kind_of?(Array) ? 'IN' : '=')
                    when :like then 'LIKE'
                    when :in then 'IN'
                    else raise ArgumentError.new('Operator type not supported')
                  end
                  normalize(["#{@database[@options[:class]][k.value.to_sym].to_sql} #{op} ?", v], collector)
                end
              else
                @has_id = true if k == :id
                case v
                when Array then
                  normalize(["#{@database[@options[:class]][k.to_sym].to_sql} IN ?", v], collector)
                when SelectStatement then
                  normalize(["#{@database[@options[:class]][k.to_sym].to_sql} IN ?", v], collector)
                else
                  normalize(["#{@database[@options[:class]][k.to_sym].to_sql} = ?", v], collector)
                end
              end
            end
          when Array then
            return collector if clause.empty?
            @has_id = true if clause.first =~ /(^|\s|\`)id(\`|\s|\=|\<)/ && !clause[1].kind_of?(SelectStatement)
            collector << escape(clause)
          when String then
            @has_id = true if clause =~ /(^|\s|\`)id(\`|\s|\=|\<)/
            collector << clause
          else raise NormalizationError.new(clause)              
        end
        
        return collector
      end
      
      def escape(conditions)
        clause = conditions.shift

        clause.gsub(/\?/) do |x|
          # Check if the condition is an in, clause.
          case conditions.first
          when Array then
            '(' << conditions.shift.map { |c| @database.quote_value(c) }.join(', ') << ')'
          when SelectStatement then
            '(' << conditions.shift.to_sql << ')'
          else
            @database.quote_value(conditions.shift)
          end
        end
      end
      
      def has_id?
        normalized_conditions
        @has_id
      end
      
      def normalized_conditions
        
        if @normalized_conditions.nil?
          @normalized_conditions = []
          
          table = @database[@options[:class]]
          invalid_keys = nil
          
          implicits = @options.reject do |k,v|            
            standard_key = DataMapper::Session::FIND_OPTIONS.include?(k)
            (invalid_keys ||= []) << k if !standard_key && table[k.to_sym].nil?
            standard_key
          end
          
          raise "Invalid options: #{invalid_keys.inspect}" unless invalid_keys.nil?
          
          normalize(implicits, @normalized_conditions)
          
          if @options.has_key?(:conditions)
            normalize(@options[:conditions], @normalized_conditions)
          end
          
        end
        
        return @normalized_conditions          
      end
      
      def empty?
        normalized_conditions.empty?
      end
      
      def to_a
        normalized_conditions
      end
    end
    
  end
end