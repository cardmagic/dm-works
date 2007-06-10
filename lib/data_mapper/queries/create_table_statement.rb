module DataMapper
  module Queries
    
    class CreateTableStatement
      
      def initialize(database, klass)
        @database, @klass = database, klass
      end
      
      def to_sql
        table = @database[@klass]
        
        sql = "CREATE TABLE " << table.to_sql << " ("
        
        sql << table.columns.map do |column|
          column_long_form(column)
        end.join(', ')
        
        sql << ", PRIMARY KEY (#{table.key.to_sql}))"
        
        return sql
      end
      
      def column_long_form(column)
        long_form = "#{column.to_sql} #{@database.adapter.class::TYPES[column.type] || column.type}"
        
        long_form << "(#{column.size})" unless column.size.nil?
        long_form << " NOT NULL" unless column.nullable?
        long_form << " " << @database.syntax(:auto_increment) if column.key?
        long_form << " default #{column.options[:default]}" if column.options.has_key?(:default)
        
        return long_form
      end
      
    end
    
  end
end