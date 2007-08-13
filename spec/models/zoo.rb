class Zoo < DataMapper::Base
  property :name, :string
  property :notes, :text
  
  has_many :exhibits
  advanced_has_many :exhibits2, :class_name => 'Exhibit'
end