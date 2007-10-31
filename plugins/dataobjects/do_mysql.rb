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
    
    class Field
      attr_reader :name, :type
      
      def initialize(ptr)
        @name, @type = ptr.name.to_s, ptr.type.to_s
      end
    end
    
    class Reader < DataObject::Reader
      
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
          @field_count = @reader.field_count
          @state = STATE_OPEN
          
          @native_fields, @fields = Mysql_c.mysql_c_fetch_field_types(@reader, @field_count), Mysql_c.mysql_c_fetch_field_names(@reader, @field_count)

          raise UnknownError, "An unknown error has occured while trying to process a MySQL query. There were no fields in the resultset\n#{Mysql_c.mysql_error(db)}" if @native_fields.empty?
          
          @has_rows = !(@row = Mysql_c.mysql_c_fetch_row(@reader)).nil?
        end
      end
      
      def close
        if @state == STATE_OPEN
          Mysql_c.mysql_free_result(@reader)
          @state = STATE_CLOSED
          true
        else
          false
        end
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
      
      def current_row
        @row
      end
      
      def item(idx)
        super
        typecast(@row[idx], idx)
      end
      
      def next
        super
        @row = Mysql_c.mysql_c_fetch_row(@reader)
        close if @row.nil?
        @row ? true : nil
      end      
      
      def each
        return unless has_rows?
        
        while(true) do
          yield
          break unless self.next
        end
      end
      
      def next
        super
        @row = Mysql_c.mysql_fetch_row(@reader)
        close if @row.nil?
        @row ? true : nil
      end
      
      protected
      def native_type(col)
        super
        TYPES[@native_fields[col].type]
      end
      
      def typecast(val, idx)
        return nil if val.nil?
        field = @native_fields[idx]
        case TYPES[field]
          when "TINY"
            val != "0"
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
        if block_given?
          result = yield(reader)
          reader.close
          result
        else
          reader
        end
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