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
  
end