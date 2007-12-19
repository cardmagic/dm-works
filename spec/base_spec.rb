require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Persistence do
  
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
  
  it "should be dirty when set to nil" do
    x = Person.create(:name => 'a')
    x.should_not be_dirty
    x.name = "asdfasfd"
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

  it "should be comparable" do
    p1 = Person.create(:name => 'Sam')
    p2 = Person[p1.id]

    p1.should == p2
  end

  it "should not be equal if attributes have changed" do
    p1 = Person.create(:name => 'Sam')
    p2 = Person[p1.id]
    p2.name = "Paul"

    p1.should_not == p2
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
  
  it "should not have dirty attributes when not dirty" do
    x = Person.create(:name => 'a')
    x.should_not be_dirty
    x.dirty_attributes.should be_empty
  end
  
  it "should only list attributes that have changed in the dirty attributes hash" do
    x = Person.create(:name => 'a')
    x.name = "asdfr"
    x.should be_dirty
    x.dirty_attributes.keys.should == [:name]
  end
  
  it "should not have original_values when a new record" do
    x = Person.new(:name => 'a')
    x.original_values.should be_empty
  end
  
  it "should have original_values after saved" do
    x = Person.new(:name => 'a')
    x.save
    x.original_values.should_not be_empty
    x.original_values.keys.should include(:name)
    x.original_values[:name].should == 'a'
  end
  
  it "should have original values when created" do
    x = Person.create(:name => 'a')
    x.original_values.should_not be_empty
    x.original_values.keys.should include(:name)
    x.original_values[:name].should == "a"
  end
  
  it "should have original values when loaded from the database" do
    Person.create(:name => 'a')
    x = Person.first(:name => 'a')
    x.original_values.should_not be_empty
    x.original_values.keys.should include(:name)
    x.original_values[:name].should == "a"
  end
  
  it "should reset the original values when not new, changed then saved" do
    x = Person.create(:name => 'a')
    x.should_not be_new_record
    x.original_values[:name].should == "a"
    x.name = "b"
    x.save
    x.original_values[:name].should == "b"
  end
  
  it "should allow a value to be set to nil" do
    x = Person.create(:name => 'a')
    x.name = nil
    x.save
    x.reload!
    x.name.should be_nil    
  end

end

describe 'Properties' do

  it 'should default to public method visibility' do
    class SoftwareEngineer
      include DataMapper::Persistence
      
      set_table_name 'people'
      property :name, :string
    end

    public_properties = SoftwareEngineer.public_instance_methods.select { |m| ["name", "name="].include?(m) }
    public_properties.length.should == 2
  end

  it 'should respect protected property options' do
    class SanitationEngineer
      include DataMapper::Persistence

      set_table_name 'people'
      property :name, :string, :reader => :protected
      property :age, :integer, :writer => :protected
    end

    protected_properties = SanitationEngineer.protected_instance_methods.select { |m| ["name", "age="].include?(m) }
    protected_properties.length.should == 2
  end

  it 'should respect private property options' do
    class ElectricalEngineer
      include DataMapper::Persistence

      set_table_name 'people'
      property :name, :string, :reader => :private
      property :age, :integer, :writer => :private
    end

    private_properties = ElectricalEngineer.private_instance_methods.select { |m| ["name", "age="].include?(m) }
    private_properties.length.should == 2
  end

  it 'should set both reader and writer visibiliy when accessor option is passed' do
    class TrainEngineer
      include DataMapper::Persistence

      property :name, :string, :accessor => :private
    end

    private_properties = TrainEngineer.private_instance_methods.select { |m| ["name", "name="].include?(m) }
    private_properties.length.should == 2
  end

  it 'should only be listed in attributes if they have public getters' do
    class SalesEngineer
      include DataMapper::Persistence

      set_table_name 'people'
      property :name, :string
      property :age, :integer, :reader => :private
    end

    @sam = SalesEngineer.first(:name => 'Sam')
    # note: id default key gets a public reader by default (but writer is protected)
    @sam.attributes.should == {:id => @sam.id, :name => @sam.name}
  end

  it 'should not allow mass assignment if private or protected' do
    class ChemicalEngineer
      include DataMapper::Persistence

      set_table_name 'people'
      property :name, :string, :writer => :private
      property :age, :integer
    end

    @sam = ChemicalEngineer.first(:name => 'Sam')
    @sam.attributes = {:name => 'frank', :age => 101}
    @sam.age.should == 101
    @sam.name.should == 'Sam'
  end

  it 'should allow :protected to be passed as an alias for a public reader, protected writer' do
    class CivilEngineer
      include DataMapper::Persistence

      set_table_name 'people'
      property :name, :string, :protected => true
    end

    CivilEngineer.public_instance_methods.should include("name")
    CivilEngineer.protected_instance_methods.should include("name=")
  end

  it 'should allow :private to be passed as an alias for a public reader, private writer' do
    class AudioEngineer
      include DataMapper::Persistence

      set_table_name 'people'
      property :name, :string, :private => true
    end

    AudioEngineer.public_instance_methods.should include("name")
    AudioEngineer.private_instance_methods.should include("name=")
  end
  
  it 'should raise an error when invalid options are passsed' do
    lambda do
      class JumpyCow
        include DataMapper::Persistence

        set_table_name 'animals'
        property :name, :string, :laze => true
      end
    end.should raise_error(ArgumentError)
  end

  it 'should raise an error when the first argument to index isnt an array' do
    lambda do
      class JumpyCow
        include DataMapper::Persistence

        set_table_name 'animals'
        index :name, :parent
      end
    end.should raise_error(ArgumentError)
  end
end
