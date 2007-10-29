module DataMapper
  module Adapters
    module Sql
      
      # Quoting is a mixin that extends your DataMapper::Database singleton-class
      # to allow for object-name and value quoting to be exposed to the queries.
      #
      # DESIGN: Is there any need for this outside of the query objects? Should
      # we just include it in our query object subclasses and not rely on a Quoting
      # mixin being part of the "standard" Adapter interface?
      module Quoting

        def quote_table_name(name)
          name.ensure_wrapped_with(self.class::TABLE_QUOTING_CHARACTER)
        end

        def quote_column_name(name)
          name.ensure_wrapped_with(self.class::COLUMN_QUOTING_CHARACTER)
        end

        def quote_value(value)
          return 'NULL' if value.nil?

          case value
            when Numeric then quote_numeric(value)
            when String then quote_string(value)
            when Class then quote_class(value)
            when Time then quote_time(value)
            when DateTime then quote_datetime(value)
            when Date then quote_date(value)
            when TrueClass, FalseClass then quote_boolean(value)
            when Array then quote_array(value)
            else 
              if value.respond_to?(:to_sql)
                value.to_sql
              else
                raise "Don't know how to quote #{value.inspect}"
              end
          end
        end
        
        def quote_numeric(value)
          value.to_s
        end
        
        def quote_string(value)
          "'#{value.gsub("'", "''")}'"
        end
        
        def quote_class(value)
          "'#{value.name}'"
        end
        
        def quote_time(value)
          "'#{value.xmlschema}'"
        end
        
        def quote_datetime(value)
          "'#{value}'"
        end
        
        def quote_date(value)
          "'#{value.strftime("%Y-%m-%d")}'"
        end
        
        def quote_boolean(value)
          value.to_s.upcase
        end
        
        def quote_array(value)
          "(#{value.map { |entry| quote_value(entry) }.join(', ')})"
        end

      end # module Quoting
    end
  end
end