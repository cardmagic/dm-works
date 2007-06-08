module DataMapper
  module Queries
    
    class InsertStatement
      
      def initialize(database, instance)
        @database, @instance = database, instance
      end
      
      # The only thing this method is responsible for is generating the insert statement.
      # It is the database adapters responsibility to get the last inserted id
      def to_sql
        
        table = @database[@instance.class]
        
        keys = []
        values = []
        
        @instance.dirty_attributes.each_pair { |k,v| keys << table[k].to_sql; values << v }
        
        # Formatting is a bit off here, but it looks nicer in the log this way.
        sql = "INSERT INTO #{table.to_sql} (#{keys.join(', ')}) \
VALUES (#{values.map { |v| @database.quote_value(v) }.join(', ')})"
      end
      
    end
    
  end
end