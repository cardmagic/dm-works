require 'data_mapper/adapters/sql/commands/advanced_conditions'
require 'data_mapper/adapters/sql/commands/loader'

module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class AdvancedLoadCommand
      
          attr_reader :conditions, :session, :options
          
          def initialize(adapter, session, primary_class, options = {})
            @adapter, @session, @primary_class = adapter, session, primary_class
            
            @options, conditions_hash = partition_options(options)
            @order = @options[:order]
            @limit = @options[:limit]
            @offset = @options[:offset]
            @reload = @options[:reload]
            @instance_id = @options[:id]
            @conditions = AdvancedConditions.new(@adapter, self, conditions_hash)
            @loaders = Hash.new { |h,k| h[k] = Loader.new(self, k) }
          end
          
          def inspect
            @options.inspect
          end
          
          def conditions
            @conditions
          end
          
          # If +true+ then force the command to reload any objects
          # already existing in the IdentityMap when executing.
          def reload?
            @reload
          end
          
          # Determine if there is a limitation on the number of
          # instances returned in the results. If +nil+, no limit
          # is set. Can be used in conjunction with #offset for
          # paging through a set of results.
          def limit
            @limit
          end
          
          # Used in conjunction with #limit to page through a set
          # of results.
          def offset
            @offset
          end
          
          def call
            
            # This is all just an optimization concerning finding
            # objects when only a key is passed. Pre-check the IdentityMap
            # first when it's a single id, and if present, return the object.
            # If it's an Array, then look for all matching objects, and
            # if you find as many results as keys in the clause, return
            # them and skip query execution.
            # This should be moved to another method...
            if instance_id && !reload?
              if instance_id.kind_of?(Array)
                instances = instance_id.map do |id|
                  @session.identity_map.get(klass, id)
                end.compact
              
                return instances if instances.size == instance_id.size
              else
                instance = @session.identity_map.get(klass, instance_id)
                return instance unless instance.nil?
              end
            end
          
            # This is the actual execution of the query, and loading
            # of objects. We should move the database specific stuff out
            # to an Adapter#execute method that just yields Arrays for
            # rows. Simpler cleanup.
            reader = execute(to_sql)
          
            results = if eof?(reader)
              nil
            elsif limit == 1 || ( instance_id && !instance_id.kind_of?(Array) )
              fetch_one(reader)
            else
              fetch_all(reader)
            end
            
            close_reader(reader)
            
            return results
          end
          
          # TODO: fetch_one and fetch_all depended on this method from the
          # old LoadCommand. Unnecessary now. Just need to figure out how
          # to wire up the call method.
          def load_instances
            raise NotImplementedError.new
          end
          
          # Generate a select statement based on the initialization
          # arguments.
          def to_sql
            parameters = nil
            
            sql = 'SELECT ' << columns_for_select.join(', ')
            sql << ' FROM ' << from_table_name            
            
            included_associations.each do |association|
              sql << ' ' << association.to_sql
            end
            
            shallow_included_associations.each do |association|
              sql << ' ' << association.to_shallow_sql
            end
            
            unless conditions.empty?
              where_clause, parameters = conditions.to_parameterized_sql
              sql << ' WHERE (' << where_clause << ')'
            end
            
            unless @order.nil?
              sql << ' ORDER BY ' << @order.to_s
            end
        
            unless @limit.nil?
              sql << ' LIMIT ' << @limit.to_s
            end
            
            unless @offset.nil?
              sql << ' OFFSET ' << @offset.to_s
            end
            
            return escape_parameterized_sql(sql, parameters)
          end
          
          def qualify_columns?
            return @qualify_columns unless @qualify_columns.nil?
            @qualify_columns = !(included_associations.empty? && shallow_included_associations.empty?)
          end
          
          private
            
            def escape_parameterized_sql(statement, parameters)
              statement.gsub(/\?/) do |x|
                # Check if the condition is an in, clause.
                case parameter = parameters.shift
                when Array then
                  '(' << parameter.map { |c| @adapter.quote_value(c) }.join(', ') << ')'
                when LoadCommand then
                  '(' << parameter.to_sql << ')'
                else
                  @adapter.quote_value(parameter)
                end
              end
            end
            
            # Return the Sql-escaped columns names to be selected in the results.
            def columns_for_select
              @columns_for_select || begin
                qualify_columns = qualify_columns?
                @columns_for_select = []
                
                columns.each_with_index do |column,i|
                  class_for_loader = column.table.klass
                  @loaders[class_for_loader].add_column(column, i) if class_for_loader
                  @columns_for_select << column.to_sql(qualify_columns)
                end
                
                @columns_for_select
              end
              
            end
            
            # Returns the DataMapper::Adapters::Sql::Mappings::Column instances to
            # be selected in the results.
            def columns
              @columns || begin
                @columns = primary_class_columns
                @columns += included_columns
                
                included_associations.each do |assoc|
                  @columns += assoc.association_columns
                end
                
                shallow_included_associations.each do |assoc|
                  @columns += assoc.join_columns
                end
                
                @columns
              end
            end
            
            # Returns the default columns for the primary_class_table,
            # or maps symbols specified in a +:select+ option to columns
            # in the primary_class_table.
            def primary_class_columns
              @primary_class_columns || @primary_class_columns = begin
                if @options.has_key?(:select)
                  case x = @options[:select]
                  when Array then x
                  when Symbol then [x]
                  else raise ':select option must be a Symbol, or an Array of Symbols'
                  end.map { |name| primary_class_table[name] }
                else
                  primary_class_table.columns.reject { |column| column.lazy? }
                end
              end
            end
            
            def included_associations
              @included_associations || @included_associations = begin
                associations = primary_class_table.associations
                include_options.map do |name|
                  associations[name]
                end.compact
              end
            end
            
            def shallow_included_associations
              @shallow_included_associations || @shallow_included_associations = begin
                associations = primary_class_table.associations
                shallow_include_options.map do |name|
                  associations[name]
                end.compact
              end
            end
            
            def included_columns
              @included_columns || @included_columns = begin
                include_options.map do |name|
                  primary_class_table[name]
                end.compact
              end
            end
            
            def include_options
              @include_options || @include_options = begin
                case x = @options[:include]
                when Array then x
                when Symbol then [x]
                else []
                end
              end
            end
            
            def shallow_include_options
              @shallow_include_options || @shallow_include_options = begin
                case x = @options[:shallow_include]
                when Array then x
                when Symbol then [x]
                else []
                end
              end
            end
            
            # Determine if a Column should be included based on the
            # value of the +:include+ option.
            def include_column?(name)
              !primary_class_table[name].lazy? || include_options.includes?(name)
            end

            # Return the Sql-escaped table name of the +primary_class+.
            def from_table_name
              @from_table_name || (@from_table_name = @adapter[@primary_class].to_sql)
            end
            
            # Returns the DataMapper::Adapters::Sql::Mappings::Table for the +primary_class+.
            def primary_class_table
              @primary_class_table || (@primary_class_table = @adapter[@primary_class])
            end
            
            def partition_options(options)
              find_options = @adapter.class::FIND_OPTIONS
              conditions_hash = {}
              options_hash = {}
              options.each do |key,value|
                if key != :conditions && find_options.include?(key)
                  options_hash[key] = value
                else
                  conditions_hash[key] = value
                end
              end
              
              [ options_hash, conditions_hash ]
            end
          
          protected
          
            def count_rows(reader)
              raise NotImplementedError.new
            end

            def close_reader(reader)
              raise NotImplementedError.new
            end

            def execute(sql)
              raise NotImplementedError.new
            end

            def fetch_one(reader)
              fetch_all(reader).first
            end

            def fetch_all(reader)
              load_instances(reader.fetch_fields.map { |field| field.name }, reader)
            end
          
        end # class LoadCommand
      end # module Commands
    end # module Sql
  end # module Adapters
end # module DataMapper