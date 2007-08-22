class Person < DataMapper::Base
  property :name, :string
  property :age, :integer
  property :occupation, :string
  property :type, :class
  property :notes, :text, :lazy => true
  
  embed :address do
    property :street, :string
    property :city, :string
    property :state, :string, :size => 2
    property :zip_code, :string, :size => 10
  end
  
end