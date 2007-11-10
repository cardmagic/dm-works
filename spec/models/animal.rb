class Animal < DataMapper::Base
  property :name, :string, :default => "No Name"
  property :notes, :text
  property :nice, :boolean
  
  has_one :favourite_fruit, :class => 'Fruit', :foreign_key => 'devourer_id'
  has_and_belongs_to_many :exhibits
end