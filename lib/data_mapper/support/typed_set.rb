require 'set'

module DataMapper
  module Support
    class TypedSet < Set
      
      alias __append <<
      alias __init initialize
      
      def initialize(*types)
        super()
        @__types = types
      end
      
      def <<(item)
        raise ArgumentError.new("#{item.inspect} must be a kind of: #{@__types.inspect}") unless @__types.any? { |type| type === item }
        __append(item)
      end
      
      def concat(values)
        [*values].each { |item| self << item }
        self
      end
      
      def inspect
        "#<DataMapper::Support::TypedSet#{@__types.inspect}: {#{entries.inspect[1...-1]}}>"
      end
    end
  end
end