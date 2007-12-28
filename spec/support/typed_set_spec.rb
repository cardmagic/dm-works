require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Support::TypedSet do
  
  it "should accept objects of a defined type, and raise for others" do
    
    s = DataMapper::Support::TypedSet.new(Zoo, Animal)
    
    lambda { s << Zoo.first }.should_not raise_error(ArgumentError)
    s.size.should == 1
    
    lambda { s << Animal.first }.should_not raise_error(ArgumentError)
    s.size.should == 2
    
    lambda { s << Exhibit.first }.should raise_error(ArgumentError)
    s.size.should == 2
    
  end
  
end