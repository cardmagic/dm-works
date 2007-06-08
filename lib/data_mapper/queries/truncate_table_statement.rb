module DataMapper
  module Queries
    
    class TruncateTableStatement
      
      def initialize(database, klass)
        @database, @klass = database, klass
      end
      
      def to_sql
        "TRUNCATE TABLE " << @database[@klass].to_sql
      end
      
    end
    
  end
end