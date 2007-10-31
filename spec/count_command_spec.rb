require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Adapters::AbstractAdapter do
    
  before(:all) do
    fixtures(:zoos)
  end

  it "should return a count of the selected table" do
    Zoo.count.should be_a_kind_of(Integer)
    Zoo.count.should == Zoo.all.size
  end
end
