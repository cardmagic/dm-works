module DataMapper
  module Adapters
    module Sql
      module Commands
    
        class AdvancedLoadCommand
      
          attr_reader :conditions, :options
          
          def initialize(adapter, session, primary_class, options = {})
            @adapter, @session, @primary_class, @options = adapter, session, primary_class, options
            
            @order = @options[:order]
            @limit = @options[:limit]
            @offset = @options[:offset]
            @reload = @options[:reload]
            @instance_id = @options[:id]
            @conditions = @options[:conditions]
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
          
          # Generate a select statement based on the initialization
          # arguments.
          def to_sql            
            sql = 'SELECT ' << columns_for_select.join(', ')
            sql << ' FROM ' << from_table_name            
            
            included_associations.each do |association|
              sql << ' ' << association.to_sql
            end
            
            return sql
          end
          
          private
          
            # Return the Sql-escaped columns names to be selected in the results.
            def columns_for_select
              @columns_for_select || @columns_for_select = begin
                qualify_columns = !included_associations.empty?
                columns.map { |column| column.to_sql(qualify_columns) }
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
          
        end # class LoadCommand
      end # module Commands
    end # module Sql
  end # module Adapters
end # module DataMapper