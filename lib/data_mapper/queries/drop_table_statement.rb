module DataMapper
  module Queries
    
    class DropTableStatement
      
      def initialize(database, klass)
        @database, @klass = database, klass
      end
      
      def to_sql
        "DROP TABLE #{@database[@klass].to_sql}"
      end
      
    end
    
  end
end