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
            
            @load_by_id = @options.has_key?(:id) && @options.size == 1
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
          
          def load_by_id?
            @load_by_id
          end
          
          def call
            
            results = []
            
            # Check to see if the query is for a specific id (or set of ids)
            # and return them if found.
            if load_by_id? && !reload? && instance_id = @options[:id]
              
              # Return as many of the id's from the Array as possible.
              # Query for the remainder. If the size of the Array and
              # the size of the found objects match, just return.
              if instance_id.kind_of?(Array)
                found_ids = []
                
                instance_id.each_with_index do |id|
                  if instance = @session.identity_map.get(@primary_class, id)
                    found_ids << id
                    results << instance 
                  end
                end
                
                # If all instances were found, then return immediately.
                return results if results.size == instance_id.size
                
                # If only some instances were found, then remove the
                # ids that were found from the list.
                @options[:id] -= found_ids
              else
                # If the id is for only a single record, attempt to find it.
                if instance = @session.identity_map.get(klass, instance_id)
                  return instance
                end
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
          def load_instances(fields, rows)            
            table = @adapter[klass]
            
            set = []
            columns = {}
            key_ordinal = nil
            key_column = table.key
            type_ordinal = nil
            type_column = nil
            
            fields.each_with_index do |field, i|
              column = table.find_by_column_name(field.to_sym)
              key_ordinal = i if column.key?
              type_ordinal, type_column = i, column if column.name == :type
              columns[column] = i
            end
            
            if type_ordinal
              
              tables = Hash.new() do |h,k|
                
                table_for_row = @adapter[k.blank? ? klass : type_column.type_cast_value(k)]
                key_ordinal_for_row = nil
                columns_for_row = {}
                
                fields.each_with_index do |field, i|
                  column = table_for_row.find_by_column_name(field.to_sym)
                  key_ordinal_for_row = i if column.key?
                  columns_for_row[column] = i
                end
                
                h[k] = [ table_for_row.klass, table_for_row.key, key_ordinal_for_row, columns_for_row ]
              end
              
              rows.each do |row|
                klass_for_row, key_column_for_row, key_ordinal_for_row, columns_for_row = *tables[row[type_ordinal]]
                
                load_instance(
                  create_instance(
                    klass_for_row,
                    key_column_for_row.type_cast_value(row[key_ordinal_for_row])
                  ),
                  columns_for_row,
                  row,
                  set
                )
              end
            else
              rows.each do |row|
                load_instance(
                  create_instance(
                    klass,
                    key_column.type_cast_value(row[key_ordinal])
                  ),
                  columns,
                  row,
                  set
                )
              end
            end
            
            set.dup
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