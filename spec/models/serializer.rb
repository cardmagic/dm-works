class Serializer < DataMapper::Base
  property :content, :object, :lazy => false
end