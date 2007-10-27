require 'data_mapper/adapters/sql/commands/conditions'
require 'data_mapper/adapters/sql/commands/loader'

module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class LoadCommand
      
          attr_reader :conditions, :session, :options
          
          def initialize(adapter, session, primary_class, options = {})
            @adapter, @session, @primary_class = adapter, session, primary_class
            
            @options, conditions_hash = partition_options(options)
            
            @order = @options[:order]
            @limit = @options[:limit]
            @offset = @options[:offset]
            @reload = @options[:reload]
            @instance_id = conditions_hash[:id]
            @conditions = Conditions.new(@adapter, self, conditions_hash)
            @loaders = Hash.new { |h,k| h[k] = Loader.new(self, k) }
          end
          
          # Display an overview of load options at a glance.          
          def inspect
            <<-EOS.compress_lines % (object_id * 2)
              #<#{self.class.name}:0x%x
                @database=#{@adapter.name}
                @reload=#{@reload.inspect}
                @order=#{@order.inspect}
                @limit=#{@limit.inspect}
                @offset=#{@offset.inspect}
                @options=#{@options.inspect}>
            EOS
          end
                              
          # Access the Conditions instance
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
            
            # Check to see if the query is for a specific id and return if found
            #
            # NOTE: If the :id option is an Array:
            # We could search for loaded instance ids and reject from
            # the Array for already loaded instances, but working under the
            # assumption that we'll probably have to issue a query to find
            # at-least some of the instances we're looking for, it's faster to
            # just skip that and go straight for the query.
            unless reload? || @instance_id.blank? || @instance_id.is_a?(Array)
              # If the id is for only a single record, attempt to find it.
              if instance = @session.identity_map.get(@primary_class, @instance_id)
                return [instance]
              end
            end
            
            results = []
            
            # Execute the statement and load the objects.
            @adapter.execute(*to_parameterized_sql) do |reader, num_rows|
              if @options.has_key?(:intercept_load)
                load(reader, &@options[:intercept_load])
              else
                load(reader)
              end
            end
            
            results += @loaders[@primary_class].loaded_set
            return results
          end
          
          def load(reader)          
            # The following blocks are identical aside from the yield.
            # It's written this way to avoid a conditional within each
            # iterator, and to take advantage of the performance of
            # yield vs. Proc#call.
            if block_given?
              reader.each do
                @loaders.each_pair do |klass,loader|
                  row = reader.current_row
                  yield(loader.materialize(row), @columns, row)
                end
              end
            else
              reader.each do
                @loaders.each_pair do |klass,loader|
                  loader.materialize(reader.current_row)
                end
              end
            end
          end
          
          # Generate a select statement based on the initialization
          # arguments.
          def to_parameterized_sql
            parameters = []
            
            sql = 'SELECT ' << columns_for_select.join(', ')
            sql << ' FROM ' << from_table_name            
            
            included_associations.each do |association|
              sql << ' ' << association.to_sql
            end
            
            shallow_included_associations.each do |association|
              sql << ' ' << association.to_shallow_sql
            end
            
            unless conditions.empty?
              where_clause, *parameters = conditions.to_parameterized_sql
              sql << ' WHERE ' << where_clause
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
            
            parameters.unshift(sql)
          end
          
          def qualify_columns?
            return @qualify_columns unless @qualify_columns.nil?
            @qualify_columns = !(included_associations.empty? && shallow_included_associations.empty?)
          end
          
          private            
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
              @from_table_name || (@from_table_name = @adapter.table(@primary_class).to_sql)
            end
            
            # Returns the DataMapper::Adapters::Sql::Mappings::Table for the +primary_class+.
            def primary_class_table
              @primary_class_table || (@primary_class_table = @adapter.table(@primary_class))
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
          
        end # class LoadCommand
      end # module Commands
    end # module Sql
  end # module Adapters
end # module DataMapper