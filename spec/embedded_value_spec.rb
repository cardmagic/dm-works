require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::EmbeddedValue do
    
  before(:all) do
    @bob = Person[:name => 'Bob']
  end
  
  it 'should proxy getting values for you' do
    @bob.address.street.should == '123 Happy Ln.'
  end
  
  it 'should return a sub-class of the containing class' do
    @bob.address.class.should be(Person::Address)
  end
  
  it 'should allow definition of instance methods' do
    @bob.address.city_state_zip_code.should == 'Dallas, TX 75000'
  end
  
  it 'should allow you to use your own classes as well as long as they inherit from EmbeddedValue' do
    @bob.location.to_s.should == 'Dallas, TX'
  end

  it 'should not require prefix' do
    class PointyHeadedBoss < DataMapper::Base
      set_table_name 'people'

      property :name, :string

      embed :address do
        # don't provide a prefix option to embed
        # so the column names of these properties gets nothing auto-prepended
        property :address_street, :string
        property :address_city, :string
      end
    end

    @sam = PointyHeadedBoss[:name => 'Sam']
    @sam.address.address_street.should == '1337 Duck Way'
  end

  it 'should add convenience methods to the non-embedded base' do
    class Employee < DataMapper::Base
      set_table_name 'people'

      property :name, :string

      embed :address, :prefix => true do
        property :street, :string
        property :city, :string
      end
    end

    @sam = Employee[:name => 'Sam']
    @sam.address_street.should == '1337 Duck Way'
  end

  it 'should support lazy loading of embedded properties' do
    class Human < DataMapper::Base
      set_table_name 'people'

      property :name, :string

      embed :address, :lazy => true, :prefix => true do
        property :street, :string
        property :city, :string
      end
    end

    @sam = Human[:name => 'Sam']
    @sam.address.street.should == '1337 Duck Way'
  end
end
