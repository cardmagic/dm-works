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
    Person.table.should be_a_kind_of DataMapper::Adapters::Sql::Mappings::Table
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