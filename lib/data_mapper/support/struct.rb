module DataMapper
  module Support
    class Struct
      
      def self.define(raw_fields)
        
        normalized_fields = raw_fields.map { |field| Inflector.underscore(field).to_sym }
        
        Class.new(self) do
          define_method(:fields) do
            normalized_fields
          end
        end
      end
      
      def initialize(values)
        @values = values
      end

      def method_missing(sym, *args)
        @values[fields.index(sym)]
      end
      
    end # class Struct
  end # module Support
end # module DataMapper