class Career #< DataMapper::Base
  include DataMapper::Persistence
  
  property :name, :string, :key => true
  
  has_many :followers, :class => 'Person'
end