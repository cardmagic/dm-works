class Exhibit < DataMapper::Base
  property :name, :string
  
  validates_presence_of :name
  
  belongs_to :zoo
  has_and_belongs_to_many :animals
end