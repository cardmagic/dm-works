require 'data_mapper/queries/select_statement'
require 'data_mapper/queries/insert_statement'
require 'data_mapper/queries/update_statement'
require 'data_mapper/queries/delete_statement'
require 'data_mapper/queries/truncate_table_statement'
require 'data_mapper/queries/create_table_statement'
require 'data_mapper/queries/drop_table_statement'
require 'data_mapper/queries/table_exists_statement'
require 'data_mapper/queries/connection'

module DataMapper
  
  # An Adapter is really a Factory for three types of object,
  # so they can be selectively sub-classed where needed.
  # 
  # The first type is a Query. The Query is an object describing
  # the database-specific operations we wish to perform, in an
  # abstract manner. For example: While most if not all databases
  # support a mechanism for limiting the size of results returned,
  # some use a "LIMIT" keyword, while others use a "TOP" keyword.
  # We can set a SelectStatement#limit field then, and allow
  # the adapter to override the underlying SQL generated.
  # Refer to DataMapper::Queries.
  # 
  # The second type provided by the Adapter is a DataMapper::Connection.
  # This allows us to execute queries and return results in a clear and
  # uniform manner we can use throughout the DataMapper.
  #
  # The final type provided is a DataMapper::Transaction.
  # Transactions are duck-typed Connections that span multiple queries.
  #
  # Note: It is assumed that the Adapter implements it's own
  # ConnectionPool if any since some libraries implement their own at
  # a low-level, and it wouldn't make sense to pay a performance
  # cost twice by implementing a secondary pool in the DataMapper itself.
  # If the library being adapted does not provide such functionality,
  # DataMapper::Support::ConnectionPool can be used.
  module Adapters
      
    # You must inherit from the Abstract::Adapter, and implement the
    # required methods to adapt a database library for use with the DataMapper.
    #
    # NOTE: By inheriting from AbstractAdapter, you get a copy of all the
    # standard sub-modules (Quoting, Coersion and Queries) in your own Adapter.
    # You can extend and overwrite these copies without affecting the originals.
    class AbstractAdapter
  
      # Instantiate an Adapter by passing it a DataMapper::Database
      # object for configuration.
      def initialize(configuration)
        @configuration = configuration
      end
  
      def connection(&block)
        raise NotImplementedError.new
      end
  
      def transaction(&block)
        raise NotImplementedError.new
      end
      
      # This callback copies and sub-classes modules and classes
      # in the AbstractAdapter to the inherited class so you don't
      # have to copy and paste large blocks of code from the
      # AbstractAdapter.
      # 
      # Basically, when inheriting from the AbstractAdapter, you
      # aren't just inheriting a single class, you're inheriting
      # a whole graph of Types. For convenience.
      def self.inherited(base)
        
        quoting = base.const_set('Quoting', Module.new)
        quoting.send(:include, Quoting)
        
        coersion = base.const_set('Coersion', Module.new)
        coersion.send(:include, Coersion)
        
        queries = base.const_set('Queries', Module.new)

        Queries.constants.each do |name|
          queries.const_set(name, Class.new(Queries.const_get(name)))
        end
        
        base.const_set('TYPES', TYPES.dup)
        
        base.const_set('SYNTAX', SYNTAX.dup)
      end
      
      TYPES = {
        :integer => 'int'.freeze,
        :string => 'varchar'.freeze,
        :text => 'text'.freeze,
        :class => 'varchar'.freeze
      }
      
      SYNTAX = {
        :auto_increment => 'auto_increment'.freeze
      }
      
      # Quoting is a mixin that extends your DataMapper::Database singleton-class
      # to allow for object-name and value quoting to be exposed to the queries.
      #
      # DESIGN: Is there any need for this outside of the query objects? Should
      # we just include it in our query object subclasses and not rely on a Quoting
      # mixin being part of the "standard" Adapter interface?
      module Quoting

        def quote_table_name(name)
          name.ensure_wrapped_with('"')
        end

        def quote_column_name(name)
          name.ensure_wrapped_with('"')
        end
      
        def quote_value(value)
          return 'NULL' if value.nil?

          case value
            when Numeric then value.to_s
            when String then "'#{value.gsub("'", "''")}'"
            when Class then "'#{value.name}'"
            when Date then "'#{value.to_s}'"
            when Time, DateTime then "'#{value.strftime("%Y-%m-%d %H:%M:%S")}'"
            when TrueClass, FalseClass then value.to_s.upcase
            else raise "Don't know how to quote #{value.inspect}"
          end
        end

      end # module Quoting

      # Coersion is a mixin that allows for coercing database values to Ruby Types.
      #
      # DESIGN: Probably should handle the opposite scenario here too. I believe that's
      # currently in DataMapper::Database, which is obviously not a very good spot for
      # it.
      module Coersion

        def type_cast_value(type, raw_value)
          return nil if raw_value.nil?

          case type
          when :class then Kernel::const_get(raw_value)
          when :string, :text then
            return nil if raw_value.nil?
            value_as_string = raw_value.to_s.strip
            return nil if value_as_string.empty?
            value_as_string
          when :integer then
            return nil if raw_value.nil? || (raw_value.kind_of?(String) && raw_value.empty?)
            begin
              Integer(raw_value)
            rescue ArgumentError
              nil
            end
          else
            if respond_to?("type_cast_#{type}")
              send("type_cast_#{type}", raw_value)
            else
              raise "Don't know how to type-cast #{{ type => raw_value }.inspect }"
            end
          end      
        end

      end # module Coersion

      # You define your custom queries in a sub-module called Queries.
      # If you don't need to redefine any of the default functionality/syntax,
      # you can just create constants that point to the standard queries:
      #
      #   SelectStatement = DataMapper::Queries::SelectStatement
      #
      # It's just as easy to turn that into a sub-class however:
      #
      #   class SelectStatement < DataMapper::Queries::SelectStatement
      #   end
      #
      # You sub-class and edit instead of overwrite because you want to
      # make sure your changes only affect this database adapter and avoid
      # introducing incompatibilities into other adapters.
      module Queries
        
        # Your Connection class is one of two that will be almost completely custom.
        # Refer to DataMapper::Queries::Connection for the required interface.
        class Connection < DataMapper::Queries::Connection
        end
        
        # Reader is the other Connection related class that will be almost completely custom.
        # The idea with the Reader is to avoid creating a large Array of Hash objects to
        # represent rows since the hashes will be discarded almost immediately. Create only
        # what you need. So the reader creates a single Hash to associate columns with their
        # ordinals in the result set, then indexing the Reader for each row results in looking
        # up the column index, then the value for that index in the current row array.
        class Reader < DataMapper::Queries::Reader
        end
        
        class Result < DataMapper::Queries::Result
        end
        
        class DeleteStatement < DataMapper::Queries::DeleteStatement
        end

        class InsertStatement < DataMapper::Queries::InsertStatement
        end

        class SelectStatement < DataMapper::Queries::SelectStatement
        end

        class TruncateTableStatement < DataMapper::Queries::TruncateTableStatement
        end

        class UpdateStatement < DataMapper::Queries::UpdateStatement
        end
        
        class CreateTableStatement < DataMapper::Queries::CreateTableStatement
        end
        
        class DropTableStatement < DataMapper::Queries::DropTableStatement
        end
        
        class TableExistsStatement < DataMapper::Queries::TableExistsStatement
        end

      end # module Queries
    
    end # class AbstractAdapter
    
  end # module Adapters
end # module DataMapper