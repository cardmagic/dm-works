require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Associations::BelongsToAssociation do
  before(:all) do
    fixtures(:zoos)
  end
  
  before(:each) do
    @aviary = Exhibit.first(:name => 'Monkey Mayhem')
  end
  
  it 'has a zoo association' do
    @aviary.zoo.class.should == Zoo
    Exhibit.new.zoo.should == nil
  end
  
  it 'belongs to a zoo' do
    @aviary.zoo.should == @aviary.database_context.first(Zoo, :name => 'San Diego')
  end
  
  it "is assigned a zoo_id" do
    zoo = Zoo.first
    exhibit = Exhibit.new(:name => 'bob')
    exhibit.zoo = zoo
    exhibit.instance_variable_get("@zoo_id").should == zoo.id
    
    exhibit.save.should eql(true)
    
    zoo2 = Zoo.first
    zoo2.exhibits.should include(exhibit)
    
    exhibit.destroy!
    
    zoo = Zoo.new(:name => 'bob')
    bob = Exhibit.new(:name => 'bob')
    zoo.exhibits << bob
    zoo.save.should eql(true)
    
    zoo.exhibits.first.should_not be_a_new_record
    
    bob.destroy!
    zoo.destroy!
  end
  
  it 'can build its zoo' do
    database do |db|
      e = Exhibit.new({:name => 'Super Extra Crazy Monkey Cage'})
      e.zoo.should == nil
      e.build_zoo({:name => 'Monkey Zoo'})
      e.zoo.class == Zoo
      e.zoo.new_record?.should == true
      
      e.save
    end
  end
  
  it 'can build its zoo' do
    database do |db|
      e = Exhibit.new({:name => 'Super Extra Crazy Monkey Cage'})
      e.zoo.should == nil
      e.create_zoo({:name => 'Monkey Zoo'})
      e.zoo.class == Zoo
      e.zoo.new_record?.should == false
      e.save
    end
  end
  
  after(:all) do
    fixtures('zoos')
    fixtures('exhibits')
  end
end
