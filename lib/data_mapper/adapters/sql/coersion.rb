module DataMapper
  module Adapters
    module Sql
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
    end
  end  
end