require 'data_mapper/queries/conditions'

module DataMapper
  module Queries
    
    class SelectStatement
      
      def initialize(database, options)
        @database, @options = database, options
      end
      
      def limit
        @options[:limit]
      end
      
      def order
        @options[:order]
      end

      def klass
        @options[:class]
      end

      def has_id?
        conditions.has_id?
      end

      def escape(conditions)
        @database.escape(conditions)
      end
      
      def inspect
        @options.inspect
      end
      
      def include?(association_name)
        return false if includes.empty?
        includes.include?(association_name)
      end
      
      def includes
        list = @options[:include] ||= []
        list.kind_of?(Array) ? list : [list]
      end
      
      def reload?
        @options[:reload]
      end
      
      def select
        select_columns = @options[:select]
        unless select_columns.nil?
          select_columns = select_columns.kind_of?(Array) ? select_columns : (@options[:select] = [select_columns])
          select_columns.map { |column| @database.quote_column_name(column.to_s) }
        else
          @options[:select] = @database[klass].columns.select do |column|
            include?(column.name) || !column.lazy?
          end.map { |column| column.to_sql }
        end
      end
      
      def instance_id
        @options[:id]
      end
        
      def conditions
        @conditions ||= Conditions.new(@database, @options)
      end
      
      def table
        @table_name || @table_name = if @options.has_key?(:table)
          @database.quote_table_name(@options[:table])
        else
          @database[klass].to_sql
        end
      end

      def to_sql
        sql = 'SELECT ' << select.join(', ') << ' FROM ' << table
        
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
      
    end
    
  end
end