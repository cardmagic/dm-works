require 'logger'
require 'data_mapper/session'

# Delegates to DataMapper::database.
# Will not overwrite if a method of the same name is pre-defined.
def database(name = :default, &block)
  DataMapper::database(name, &block)
end unless methods.include?(:database)

module DataMapper
  
  # Block Syntax:
  #   Pushes the named database onto the context-stack, 
  #   yields a new session, and pops the context-stack.
  # Non-Block Syntax:
  #   Returns the current session, or if there is none,
  #   a new Session.
  def self.database(name = :default)
    unless block_given?
      Database.context.last || Session.new(Database[name].adapter)
    else
      Database.context.push(Session.new(Database[name].adapter))
      result = yield(Database.context.last)
      Database.context.pop
      result
    end
  end
  
  class DatabaseError < StandardError
    attr_accessor :options
  end
  
  class Database
    
    @databases = {}
    @context = []
    
    def self.[](name)
      @databases[name]
    end
    
    def self.context
      @context
    end
    
    def self.setup(*args)
      
      name, options = nil
      
      if args.size == 1
        name, options = :default, args[0]
      elsif args.size == 2
        name, options = args[0], args[1]
      end        
      
      current = self.new(name)
      
      options.each_pair do |k,v|
        current.send("#{k}=", v)
      end
      
      @databases[name] = current
    end
    
    def initialize(name)
      @name = name
      
      @single_threaded = true
      @adapter = nil
      @host = 'localhost'
      @database = nil
      @username = 'root'
      @password = ''
      
      @log_level = Logger::WARN
      @log_stream = nil
    end
    
    attr_reader :name, :adapter
    attr_writer :single_threaded
    attr_accessor :host, :database, :username, :password, :log_stream, :log_level
    
    def single_threaded?
      @single_threaded
    end
    
    def adapter=(value)
      if @adapter
        raise ArgumentError.new('The adapter is readonly after being set')
      end
      
      if value.is_a?(AbstractAdapter)
        @adapter = value
      else
        require "data_mapper/adapters/#{Inflector.underscore(value)}_adapter"
        adapter_class = Adapters::const_get(Inflector.classify(value) + "Adapter")
      
        @adapter = adapter_class.new(self)
      end
    end
    
    def log
      @log = Logger.new(@log_stream, File::WRONLY | File::APPEND | File::CREAT)
      @log.level = @log_level
      at_exit { @log.close }
      
      class << self
        attr_reader :log
      end
      
      return @log
    end
    
  end
  
end