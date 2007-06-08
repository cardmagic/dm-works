module DataMapper
  module Queries
    
    class DeleteStatement
      
      def initialize(database, instance)
        @database, @instance = database, instance
      end
      
      def to_sql
        "DELETE FROM " << @database[@instance.class].to_sql << " WHERE id = " << @database.quote_value(@instance.key)
      end
      
    end
    
  end
end