class Serializer #< DataMapper::Base
  include DataMapper::Persistence
  
  property :content, :object, :lazy => false
end