class Career < DataMapper::Base
  
  property :name, :string, :key => true
  
  has_many :followers, :class => 'Person'  
end