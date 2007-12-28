require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Support::TypedSet do
  
  it "should accept objects of a defined type, and raise for others" do
    
    s = DataMapper::Support::TypedSet.new(Zoo, Animal)
    
    lambda do
      s << Zoo.first
      s.size.should == 1
    end.should_not raise_error(ArgumentError)
        
    lambda do
      s << Animal.first
      s.size.should == 2
    end.should_not raise_error(ArgumentError)
    
    lambda do
      s << Exhibit.first
      s.size.should == 2
    end.should raise_error(ArgumentError)
    
  end
  
end