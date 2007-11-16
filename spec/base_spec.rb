require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Base do
  
  it "attributes method should load all lazy-loaded values" do
    Animal.first(:name => 'Cup').attributes[:notes].should == 'I am a Cup!'
  end
  
  it "mass assignment should call methods" do
    class Animal
      attr_reader :test
      def test=(value)
        @test = value + '!'
      end
    end
    
    a = Animal.new(:test => 'testing')
    a.test.should == 'testing!'
  end
  
  it "should be dirty" do
    x = Person.create(:name => 'a')
    x.should_not be_dirty
    x.name = 'dslfay'
    x.should be_dirty
  end
  
  it "should return a diff" do
    x = Person.new(:name => 'Sam', :age => 30, :occupation => 'Programmer')
    y = Person.new(:name => 'Amy', :age => 21, :occupation => 'Programmer')
    
    diff = (x ^ y)
    diff.should include(:name)
    diff.should include(:age)
    diff[:name].should eql(['Sam', 'Amy'])
    diff[:age].should eql([30, 21])
    
    x.destroy!
    y.destroy!
  end
  
  it "should update attributes" do
    x = Person.create(:name => 'Sam')
    x.update_attributes(:age => 30).should eql(true)
    x.age.should eql(30)
    x.should_not be_dirty
  end 
  
  it "should return the table for a given model" do
    Person.table.should be_a_kind_of(DataMapper::Adapters::Sql::Mappings::Table)
  end
  
  it "should support boolean accessors" do
    dolphin = Animal.first(:name => 'Dolphin')
    dolphin.should be_nice
  end

end

describe 'A new record' do
  
  before(:each) do
    @bob = Person.new(:name => 'Bob', :age => 30, :occupation => 'Sales')
  end
  
  it 'should be dirty' do
    @bob.dirty?.should == true
  end
  
  it 'set attributes should be dirty' do
    attributes = @bob.attributes.dup.reject { |k,v| k == :id }
    @bob.dirty_attributes.should == { :name => 'Bob', :age => 30, :occupation => 'Sales' }
  end
  
  it 'should be marked as new' do
    @bob.new_record?.should == true
  end
  
  it 'should have a nil id' do
    @bob.id.should == nil
  end
  
end

describe 'Properties' do

  it 'should default to public method visibility' do
    class SoftwareEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string
    end

    public_properties = SoftwareEngineer.public_instance_methods.select { |m| ["name", "name="].include?(m) }
    public_properties.length.should == 2
  end

  it 'should respect protected property options' do
    class SanitationEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string, :reader => :protected
      property :age, :integer, :writer => :protected
    end

    protected_properties = SanitationEngineer.protected_instance_methods.select { |m| ["name", "age="].include?(m) }
    protected_properties.length.should == 2
  end

  it 'should respect private property options' do
    class ElectricalEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string, :reader => :private
      property :age, :integer, :writer => :private
    end

    private_properties = ElectricalEngineer.private_instance_methods.select { |m| ["name", "age="].include?(m) }
    private_properties.length.should == 2
  end

  it 'should set both reader and writer visibiliy when accessor option is passed' do
    class TrainEngineer < DataMapper::Base
      property :name, :string, :accessor => :private
    end

    private_properties = TrainEngineer.private_instance_methods.select { |m| ["name", "name="].include?(m) }
    private_properties.length.should == 2
  end

  it 'should only be listed in attributes if they have public getters' do
    class SalesEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string
      property :age, :integer, :reader => :private
    end

    @sam = SalesEngineer[:name => 'Sam']
    # note: id default key gets a public reader by default (but writer is protected)
    @sam.attributes.should == {:id => @sam.id, :name => @sam.name}
  end

  it 'should not allow mass assignment if private or protected' do
    class ChemicalEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string, :writer => :private
      property :age, :integer
    end

    @sam = ChemicalEngineer[:name => 'Sam']
    @sam.attributes = {:name => 'frank', :age => 101}
    @sam.age.should == 101
    @sam.name.should == 'Sam'
  end

  it 'should allow :protected to be passed as an alias for a public reader, protected writer' do
    class CivilEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string, :protected => true
    end

    CivilEngineer.public_instance_methods.should include("name")
    CivilEngineer.protected_instance_methods.should include("name=")
  end

  it 'should allow :private to be passed as an alias for a public reader, private writer' do
    class AudioEngineer < DataMapper::Base
      set_table_name 'people'
      property :name, :string, :private => true
    end

    AudioEngineer.public_instance_methods.should include("name")
    AudioEngineer.private_instance_methods.should include("name=")
  end

end
