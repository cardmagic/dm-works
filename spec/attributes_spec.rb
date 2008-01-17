require File.dirname(__FILE__) + "/spec_helper"

describe "DataMapper::Attributes" do
    
  it 'should allow mass-assignment of attributes' do
    zoo = Zoo.new(:name => 'MassAssignment', :notes => 'This is a test.')
    
    zoo.name.should eql('MassAssignment')
    zoo.notes.should eql('This is a test.')
    
    zoo.attributes = { :name => 'ThroughAttributesEqual', :notes => 'This is another test.' }
    
    zoo.name.should eql('ThroughAttributesEqual')
    zoo.notes.should eql('This is another test.')
  end
  
  it "should allow custom setters" do
    zoo = Zoo.new
    
    zoo.name = 'Colorado Springs'
    zoo.name.should eql("Cheyenne Mountain")
  end
  
  it "should call custom setters on mass-assignment" do
    zoo = Zoo.new(:name => 'Colorado Springs')
    
    zoo.name.should eql("Cheyenne Mountain")
  end
  
  it "should provide an ATTRIBUTES constant" do
    Tomato::ATTRIBUTES.should == Set.new([:id, :name, :bruised])
  end
  
  it "should get attributes declared in ATTRIBUTES constant" do
    Tomato.new.attributes.should == { :id => nil, :name => 'Ugly', :bruised => true }
  end
  
end