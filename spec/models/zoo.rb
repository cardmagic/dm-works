class Zoo < DataMapper::Base
  property :name, :string
  property :notes, :text
  property :updated_at, :datetime
  
  has_many :exhibits
  
  validates_presence_of :name
end