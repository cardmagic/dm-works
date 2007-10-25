require 'postgres_c'
require 'do'

module DataObject
  module Postgres
    TYPES = Hash[*Postgres_c.constants.select {|x| x.include?("OID")}.map {|x| [Postgres_c.const_get(x), x.gsub(/_?OID$/, "")]}.flatten]
    QUOTE_STRING = "'"
    QUOTE_COLUMN = "\""
    
    class Connection < DataObject::Connection
      attr_reader :db
      
      def initialize(connection_string)
        @state = STATE_CLOSED        
        @connection_string = connection_string
      end
      
      def open
        @db = Postgres_c.PQconnectdb(@connection_string)
        if Postgres_c.PQstatus(@db) != Postgres_c::CONNECTION_OK
          raise ConnectionFailed, "The connection with connection string #{@connection_string} failed\n#{Postgres_c.PQerrorMessage(@db)}"
        end
        @state = STATE_OPEN
        true
      end
      
      def close
        Postgres_c.PQfinish(@db)
        @state = STATE_CLOSED
        true
      end
      
      def create_command(text)
        Command.new(self, text)
      end
      
    end
    
    class Reader < DataObject::Reader
      
      def initialize(db, reader)
        @reader = reader
        case Postgres_c.PQresultStatus(reader)
        when Postgres_c::PGRES_COMMAND_OK
          @records_affected = Postgres_c.PQcmdTuples(reader).to_i
          close
        when Postgres_c::PGRES_TUPLES_OK
          @fields, @field_types = [], []
          @field_count = Postgres_c.PQnfields(@reader)
          i = 0
          while(i < @field_count)
            @field_types.push(Postgres_c.PQftype(@reader, i))
            @fields.push(Postgres_c.PQfname(@reader, i))
            i += 1
          end
          @rows = Postgres_c.PQntuples(@reader)
          @has_rows = @rows > 0
          @cursor = 0
          @state = STATE_OPEN
        end
      end
      
      def close
        if @state != STATE_CLOSED
          Postgres_c.PQclear(@reader)
          @state = STATE_CLOSED
          true
        else
          false
        end
      end
      
      def data_type_name(col)
        
      end
      
      def name(col)
        super
        Postgres_c.PQfname(@reader, col)
      end
      
      def get_index(name)
        super
        @fields.index(name)
      end

      def null?(idx)
        super
        Postgres_c.PQgetisnull(@reader, @cursor, idx) != 0
      end
      
      def item(idx)
        super
        val = Postgres_c.PQgetvalue(@reader, @cursor, idx)
        typecast(val, @field_types[idx])
      end
      
      def next
        super   
        if @cursor >= @rows - 1
          @cursor = nil
          close
          return nil
        end
        @cursor += 1
        true
      end
      
      protected
      def native_type(col)
        TYPES[Postgres_c.PQftype(@reader, col)]
      end
      
      def typecast(val, field_type)
        return nil if val.nil?
        case TYPES[field_type]
          when "BOOL"
            val == "t"
          when "INT2", "INT4", "OID", "TID", "XID", "CID", "INT8"
            val.to_i
          when "FLOAT4", "FLOAT8", "NUMERIC", "CASH"
            val.to_f
          when "TIMESTAMP", "TIMETZ", "TIMESTAMPTZ"
            DateTime.parse(val)
          when "TIME"
            DateTime.parse(val).to_time
          when "DATE"
            Date.parse(val)
          else
            val
        end
      end
      
    end
    
    class ResultData < DataObject::ResultData
      
      def last_insert_row
        @last_insert_row ||= begin
          reader = @conn.create_command("select lastval()").execute_reader
          reader.item(0).to_i
        rescue QueryError
          raise NoInsertError, "You tried to get the last inserted row without doing an insert\n#{Postgres_c.PQerrorMessage(@conn.db)}"
        ensure
          reader and reader.close
        end
      end      
      
    end
    
    class Command < DataObject::Command
      
      def execute_reader
        super
        reader = Postgres_c.PQexec(@connection.db, @text)
        unless [Postgres_c::PGRES_COMMAND_OK, Postgres_c::PGRES_TUPLES_OK].include?(Postgres_c.PQresultStatus(reader))
          raise QueryError, "Your query failed.\n#{Postgres_c.PQerrorMessage(@connection.db)}QUERY: \"#{@text}\""
        end
        Reader.new(@connection.db, reader)
      end
      
      def execute_non_query
        super
        results = Postgres_c.PQexec(@connection.db, @text)
        status = Postgres_c.PQresultStatus(results)
        if status == Postgres_c::PGRES_TUPLES_OK
          Postgres_c.PQclear(results)
          raise QueryError, "Your query failed or you tried to execute a SELECT query through execute_non_reader\n#{Postgres_c.PQerrorMessage(@connection.db)}\nQUERY: \"#{@text}\""
        elsif status != Postgres_c::PGRES_COMMAND_OK
          Postgres_c.PQclear(results)
          raise QueryError, "Your query failed.\n#{Postgres_c.PQerrorMessage(@connection.db)}\nQUERY: \"#{@text}\""
        end
        rows_affected = Postgres_c.PQcmdTuples(results).to_i
        Postgres_c.PQclear(results)
        ResultData.new(@connection, rows_affected)
      end
      
    end
    
  end
end