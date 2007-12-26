require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Adapters::DataObjectAdapter do
  
  before(:all) do
    fixtures(:zoos)
  end
  
  it "should raise an argument error on create if an attribute value is not a primitive" do
    lambda { Zoo.create(:name => [nil, 'bob']) }.should raise_error(ArgumentError)
  end

end