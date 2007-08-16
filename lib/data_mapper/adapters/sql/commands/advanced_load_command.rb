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
            @include = @options[:include]
            @instance_id = @options[:id]
            @conditions = @options[:conditions]
            @join_fetch = false
            @joins = []
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
            
            if @join_fetch
              @joins.each do |association|
                sql << ' ' << association.to_sql
              end
            end
            
            return sql
          end
          
          private
          
            # Return the Sql-escaped columns names to be selected in the results.
            def columns_for_select
              @columns_for_select || @columns_for_select = begin
                columns.map { |column| column.to_sql(@join_fetch) }
              end
            end
            
            # Returns the DataMapper::Adapters::Sql::Mappings::Column instances to
            # be selected in the results.
            def columns
              @columns || begin
                @columns = if @options.has_key?(:select)
                  primary_class_table.columns.select do |column|
                    @options[:select].include?(column.name)
                  end
                else
                  primary_class_table.columns.select do |column|
                    include_column?(column.name) || !column.lazy?
                  end
                end
                
                # Return if there is no +:include+ option to evaluate.
                return @columns if @include.nil?
                
                if @include.kind_of?(Array)
                  # Return if all +:include+ parameters are columns in
                  # the primary_class_table.
                  return @columns if @include.all? do |name|
                    !primary_class_table[name].nil?
                  end
                elsif @include.kind_of?(Symbol)
                  # Return if the include is a column in the primary_class_table.
                  return @columns if primary_class_table[@include]
                  
                  primary_class_table.associations.each do |association|
                    next unless association.name == @include
                    association_table = @adapter[association.constant]
                    @columns += association_table.columns
                    @joins << association
                  end
                  
                  @join_fetch = true
                else
                  raise ':include option must be a Symbol or Array of Symbols'
                end
                
                @columns
              end
            end
            
            # Determine if a Column should be included based on the
            # value of the +:include+ option.
            def include_column?(name)
              case @include
                when nil then false
                when Symbol then @include == name
                when Array then @include.includes?(name)
                else raise ':include option must be a Symbol or Array of Symbols'
              end
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