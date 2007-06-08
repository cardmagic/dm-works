module DataMapper
  module Queries
    
    class TableExistsStatement
      
      def initialize(database, klass)
        @database, @klass = database, klass
      end
      
      def to_sql
        "SHOW TABLES LIKE #{@database.quote_value(@database[@klass].name)}"
      end
      
    end
    
  end
end