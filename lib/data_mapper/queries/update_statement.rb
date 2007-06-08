module DataMapper
  module Queries
    
    class UpdateStatement
      
      def initialize(database, instance)
        @database, @instance = database, instance
      end
      
      def to_sql
        table = @database[@instance.class]
        
        sql = "UPDATE " << table.to_sql << " SET "
        
        @instance.dirty_attributes.map do |k, v|
          sql << table[k].to_sql << " = " << @database.quote_value(v) << ", "
        end
        
        sql[0, sql.size - 2] << " WHERE #{table.key.to_sql} = " << @database.quote_value(@instance.key)
      end
      
    end
    
  end
end