class Zoo < DataMapper::Base
  property :name, :string
  property :notes, :text
  
  has_many :exhibits
end