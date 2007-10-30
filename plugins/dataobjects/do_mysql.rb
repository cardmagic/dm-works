require 'mysql_c'
require 'do'

module DataObject
  module Mysql
    TYPES = Hash[*Mysql_c.constants.select {|x| x.include?("MYSQL_TYPE")}.map {|x| [Mysql_c.const_get(x), x.gsub(/^MYSQL_TYPE_/, "")]}.flatten]    
    
    QUOTE_STRING = "\""
    QUOTE_COLUMN = "`"
    
    class Connection < DataObject::Connection
      
      def self.conns
        @conns
      end
      
      def self.conns=(val)
        @conns = val
      end
      
      self.conns = 0
      
      attr_reader :db
      
      def initialize(connection_string)
        @num = (self.class.conns += 1)
        
        @state = STATE_CLOSED
        @connection_string = connection_string
        opts = connection_string.split(" ")
        opts.each do |opt|
          k, v = opt.split("=")
          raise ArgumentError, "you specified an invalid connection component: #{opt}" unless k && v
          instance_variable_set("@#{k}", v)
        end
      end
      
      def change_database(database_name)
        @dbname = database_name
        @connection_string.gsub(/db_name=[^ ]*/, "db_name=#{database_name}")
      end
      
      def open
        @db = Mysql_c.mysql_init(nil)
        raise ConnectionFailed, "could not allocate a MySQL connection" unless @db
        conn = Mysql_c.mysql_real_connect(@db, @host, @user, @password, @dbname, @port || 0, @socket, @flags || 0)
        raise ConnectionFailed, "The connection with connection string #{@connection_string} failed\n#{Mysql_c.mysql_error(@db)}" unless conn
        @state = STATE_OPEN
        true
      end
      
      def close
        if @state == STATE_OPEN
          Mysql_c.mysql_close(@db)
          @state = STATE_CLOSED        
          true
        else
          false
        end
      end
      
      def create_command(text)
        Command.new(self, text)
      end
      
    end
    
    class Reader < DataObject::Reader
      
      def initialize(db, reader)
        @reader = reader
        result = Sqlite3_c.sqlite3_step(reader)        
        rows_affected, field_count = Sqlite3_c.sqlite3_changes(db), Sqlite3_c.sqlite3_column_count(reader)
        if field_count == 0
          @records_affected = rows_affected
          close
        else
          @field_count = field_count
          @fields, @field_types = [], []
          i = 0
          while(i < @field_count)
            @field_types.push(Sqlite3_c.sqlite3_column_type(reader, i))
            @fields.push(Sqlite3_c.sqlite3_column_name(reader, i))
            i += 1
          end
          case result
          when Sqlite3_c::SQLITE_BUSY, Sqlite3_c::SQLITE_ERROR, Sqlite3_c::SQLITE_MISUSE
            raise ReaderError, "An error occurred while trying to get the next row\n#{Sqlite3_c.sqlite3_errmsg(db)}"
          else
            @has_rows = result == Sqlite3_c::SQLITE_ROW
            @state = STATE_OPEN
            close unless @has_rows
          end
        end
      end
      
      def initialize(db, reader)        
        @reader = reader
        unless @reader
          if Mysql_c.mysql_field_count(db) == 0
            @records_affected = Mysql_c.mysql_affected_rows(db)
            close
          else
            raise UnknownError, "An unknown error has occured while trying to process a MySQL query.\n#{Mysql_c.mysql_error(db)}"
          end
        else
          @field_count = Mysql_c.mysql_num_fields(@reader)
          @state = STATE_OPEN
          self.next
          fields = Mysql_c.mysql_fetch_fields(@reader)
          @native_fields = fields
          raise UnknownError, "An unknown error has occured while trying to process a MySQL query. There were no fields in the resultset\n#{Mysql_c.mysql_error(db)}" unless fields
          @fields = fields.map {|field| field.name }
          
          @has_rows = !(@row = Mysql_c.mysql_fetch_row(@reader)).nil?
        end
      end
      
      def real_close
        Mysql_c.mysql_free_result(@reader)
      end
      
      def name(col)
        super
        @fields[col]
      end
      
      def get_index(name)
        super
        @fields.index(name)
      end
      
      def null?(idx)
        super
        @row[idx] == nil
      end
      
      def item(idx)
        super
        typecast(@row[idx], idx)
      end
      
      def each
        return unless has_rows?
        
        while(true) do
          yield
          break unless @row = Mysql_c.mysql_fetch_row(@reader)
        end
      end
      
      protected
      def native_type(col)
        super
        TYPES[@native_fields[col].type]
      end
      
      def typecast(val, idx)
        return nil if val.nil?
        field = @native_fields[idx]
        case TYPES[field.type]
          when "TINY"
            if field.max_length == 1
              val != "0"
            else
              val.to_i
            end
          when "BIT"
            val.to_i(2)
          when "SHORT", "LONG", "INT24", "LONGLONG"
            val.to_i
          when "DECIMAL", "NEWDECIMAL", "FLOAT", "DOUBLE", "YEAR"
            val.to_f
          when "TIMESTAMP", "DATETIME"
            DateTime.parse(val) rescue nil
          when "TIME"
            DateTime.parse(val).to_time rescue nil
          when "DATE"
            Date.parse(val) rescue nil
          when "NULL"
            nil
          else
            val
        end
      end      
    end
    
    class Command < DataObject::Command
      
      def execute_reader
        super
        result = Mysql_c.mysql_query(@connection.db, @text)
        # TODO: Real Error
        raise QueryError, "Your query failed.\n#{Mysql_c.mysql_error(@connection.db)}\n#{@text}" unless result == 0
        reader = Reader.new(@connection.db, Mysql_c.mysql_use_result(@connection.db))
        result = yield(reader)
        reader.close
        result
      end
      
      def execute_non_query
        super
        result = Mysql_c.mysql_query(@connection.db, @text)
        raise QueryError, "Your query failed.\n#{Mysql_c.mysql_error(@connection.db)}\n#{@text}" unless result == 0         
        reader = Mysql_c.mysql_store_result(@connection.db)
        raise QueryError, "You called execute_non_query on a query: #{@text}" if reader
        rows_affected = Mysql_c.mysql_affected_rows(@connection.db)
        Mysql_c.mysql_free_result(reader)
        return ResultData.new(@connection, rows_affected, Mysql_c.mysql_insert_id(@connection.db))
      end
      
    end
    
  end
end