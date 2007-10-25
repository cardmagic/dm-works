class Person < DataMapper::Base
  property :name, :string
  property :age, :integer
  property :occupation, :string
  property :type, :class
  property :notes, :text
  property :date_of_birth, :datetime
  
  embed :address do
    property :street, :string
    property :city, :string
    property :state, :string, :size => 2
    property :zip_code, :string, :size => 10
    
    def city_state_zip_code
      "#{city}, #{state} #{zip_code}"
    end
    
  end
  
  class Location < DataMapper::EmbeddedValue
    property :city, :string
    property :state, :string, :size => 2

    def to_s
      "#{city}, #{state}"
    end
  end
  
  embed Location
  
end