require 'yaml'

module DataMapper
  module Support
    module Serialization
      
      def to_yaml
        document = {}
        attributes.each_pair { |k,v| document[k.to_s] = v }
        document.to_yaml
      end
      
    end
  end # module Support
end # module DataMapper