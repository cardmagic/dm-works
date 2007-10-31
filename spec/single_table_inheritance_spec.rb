require File.dirname(__FILE__) + "/spec_helper"

describe 'Single Table Inheritance' do
  
  before(:all) do
    fixtures(:people)
  end
  
  it "should save and load the correct Type" do
    database do
      ted = SalesPerson.new(:name => 'Ted')
      ted.save
    
      clone = Person.first(:name => 'Ted')
      ted.should == clone
      
      ted.should be_a_kind_of(SalesPerson)
    end
  end
  
  it "secondary database should inherit the same attributes" do
    
    database(:mock) do |db|
      db.table(SalesPerson)[:name].should_not be_nil
    end
    
  end
  
end