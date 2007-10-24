class Animal < DataMapper::Base
  property :name, :string
  property :notes, :text
  
  has_one :favourite_fruit, :class => 'Fruit', :foreign_key => 'devourer_id'
  has_and_belongs_to_many :exhibits
end