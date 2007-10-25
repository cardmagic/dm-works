require 'date'

# Thanks http://www.rubyweeklynews.org/20051120
class DateTime
 def to_time
   Time.mktime(year, mon, day, hour, min, sec)
 end
 
 def to_date
   Date.new(year, mon, day)
 end
end

class Time
  def to_datetime
    DateTime.civil(year, mon, day, hour, min, sec)
  end
  
  def to_s_db
    strftime("%Y-%m-%d %X")
  end
end

module DataObject
  STATE_OPEN   = 0
  STATE_CLOSED = 1

  class Connection

    attr_reader :timeout, :database, :datasource, :server_version, :state
    
    def initialize(connection_string)
    end
    
    def begin_transaction
      # TODO: Hook this up
      Transaction.new
    end
    
    def change_database(database_name)
      raise NotImplementedError
    end
    
    def open
      raise NotImplementedError
    end
    
    def close
      raise NotImplementedError
    end
    
    def create_command(text)
      Command.new(self, text)
    end
    
    def closed?
      @state == STATE_CLOSED
    end
    
  end
  
  class Transaction
    
    attr_reader :connection
    
    def initialize(conn)
      @connection = conn
    end
    
    # Commits the transaction
    def commit
      raise NotImplementedError
    end
    
    # Rolls back the transaction
    def rollback(savepoint = nil)
      raise NotImplementedError
    end
    
    # Creates a savepoint for rolling back later (not commonly supported)
    def save(name)
      raise NotImplementedError
    end
    
  end
  
  class Reader
    include Enumerable
    
    attr_reader :field_count, :has_rows, :records_affected, :fields
    alias_method :has_rows?, :has_rows
    
    def each
      return nil unless has_rows
      while(true) do
        yield
        break unless self.next
      end
    end
    
    def current_row
      ret = []
      field_count.times do |i|
        ret[i] = item(i)
      end
      ret
    end
    
    def close
      raise NotImplementedError
    end
    
    # retrieves the Ruby data type for a particular column number
    def data_type_name(col)
      raise ReaderClosed, "You cannot ask for metadata once the reader is closed" if state_closed?      
    end
    
    # retrieves the name of a particular column number
    def name(col)
      raise ReaderClosed, "You cannot ask for metadata once the reader is closed" if state_closed?      
    end
    
    # retrives the index of the column with a particular name
    def get_index(name)
      raise ReaderClosed, "You cannot ask for metadata once the reader is closed" if state_closed?
    end
    
    def item(idx)
      raise ReaderClosed, "You cannot ask for information once the reader is closed" if state_closed?
    end

    # returns an array of hashes containing the following information
    #            
    # name:         the column name
    # index:        the index of the column
    # max_size:     the maximum allowed size of the data in the column
    # precision:    the precision (for column types that support it)
    # scale:        the scale (for column types that support it)
    # unique:       boolean specifying whether the values must be unique
    # key:          boolean specifying whether this column is, or is part
    #               of, the primary key
    # catalog:      the name of the database this column is part of
    # base_name:    the original name of the column (if AS was used,
    #               this will provide the original name)
    # schema:       the name of the schema (if supported)
    # table:        the name of the table this column is part of
    # data_type:    the name of the Ruby data type used
    # allow_null:   boolean specifying whether nulls are allowed
    # db_type:      the type specified by the DB
    # aliased:      boolean specifying whether the column has been
    #               renamed using AS
    # calculated:   boolean specifying whether the field is calculated
    # serial:       boolean specifying whether the field is a serial
    #               column
    # blob:         boolean specifying whether the field is a BLOB
    # readonly:     boolean specifying whether the field is readonly
    def get_schema
      raise ReaderClosed, "You cannot ask for metadata once the reader is closed" if state_closed?
    end
    
    # specifies whether the column identified by the passed in index
    # is null.
    def null?(idx)
      raise ReaderClosed, "You cannot ask for column information once the reader is closed" if state_closed?
    end
    
    # Consumes the next result. Returns true if a result is consumed and
    # false if none is
    def next
      raise ReaderClosed, "You cannot increment the cursor once the reader is closed" if state_closed?
    end
    
    protected
    def state_closed?
      @state == STATE_CLOSED
    end
    
    def native_type
      raise ReaderClosed, "You cannot check the type of a column once the reader is closed" if state_closed?
    end
    
  end
  
  class ResultData
    
    def initialize(conn, affected_rows, last_insert_row = nil)
      @conn, @affected_rows, @last_insert_row = conn, affected_rows, last_insert_row
    end
  
    attr_reader :affected_rows, :last_insert_row
    alias_method :to_i, :affected_rows
    
  end
  
  class Schema < Array
    
  end
  
  class Command
    
    attr_reader :text, :timeout, :connection
    
    # initialize creates a new Command object
    def initialize(connection, text)
      @connection, @text = connection, text
    end
    
    def execute_non_query
      raise LostConnectionError, "the connection to the database has been lost" if @connection.closed?
    end
    
    def execute_reader
      raise LostConnectionError, "the connection to the database has been lost" if @connection.closed?
    end
    
    def prepare
      raise NotImplementedError
    end
    
  end
  
  class NotImplementedError < StandardError
  end
  
  class ConnectionFailed < StandardError
  end
  
  class ReaderClosed < StandardError
  end
  
  class ReaderError < StandardError
  end
  
  class QueryError < StandardError
  end
  
  class NoInsertError < StandardError
  end
  
  class LostConnectionError < StandardError
  end
  
  class UnknownError < StandardError
  end
  
end