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

  it 'should default to public method visibility for all' do
    class SoftwareEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string

      embed :address, :prefix => true do
        property :city, :string
      end
    end

    @sam = SoftwareEngineer[:name => 'Sam']
    public_properties = @sam.address.class.public_instance_methods.select { |m| ["city", "city="].include?(m) }
    public_properties.length.should == 2
  end

  it 'should respect protected property options for all' do
    class SanitationEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string

      embed :address, :reader => :protected, :prefix => true do
        property :city, :string
        property :street, :string
      end
    end

    @sam = SanitationEngineer[:name => 'Sam']
    protected_properties = @sam.address.class.protected_instance_methods.select { |m| ["city", "street"].include?(m) }
    protected_properties.length.should == 2
  end

  it 'should respect private property options for all' do
    class ElectricalEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string, :reader => :private

      embed :address, :writer => :private, :prefix => true do
        property :city, :string
        property :street, :string
      end
    end

    @sam = ElectricalEngineer[:name => 'Sam']
    private_properties = @sam.address.class.private_instance_methods.select { |m| ["city=", "street="].include?(m) }
    private_properties.length.should == 2
  end

  it 'should set both reader and writer visibiliy for all when accessor option is passed' do
    class TrainEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string, :reader => :private
  
      embed :address, :accessor => :private, :prefix => true do
        property :city, :string
      end
    end

    @sam = TrainEngineer[:name => 'Sam']
    private_properties = @sam.address.class.private_instance_methods.select { |m| ["city", "city="].include?(m) }
    private_properties.length.should == 2
  end

  it 'should allow individual properties to override method visibility options passed on the block' do
    class ChemicalEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string

      embed :address, :accessor => :private, :prefix => true do
        property :city, :string
        property :street, :string, :accessor => :public
      end
    end

    @sam = ChemicalEngineer[:name => 'Sam']
    public_properties = @sam.address.class.public_instance_methods.select { |m| ["street", "street="].include?(m) }
    public_properties.length.should == 2
  end
end
