class Zoo < DataMapper::Base
  property :name, :string
  property :notes, :text
  
  has_many :exhibits
  
  validates_presence_of :name
end