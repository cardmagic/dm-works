class Person < DataMapper::Base
  property :name, :string
  property :age, :integer
  property :occupation, :string
  property :type, :class
  property :notes, :text
  property :date_of_birth, :date
  
  embed :address, :prefix => true do
    property :street, :string
    property :city, :string
    property :state, :string, :size => 2
    property :zip_code, :string, :size => 10
    
    def city_state_zip_code
      "#{city}, #{state} #{zip_code}"
    end
    
  end
end
