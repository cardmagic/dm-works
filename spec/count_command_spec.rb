describe DataMapper::Adapters::SqlAdapter do
    
  before(:all) do
    fixtures(:zoos)
  end

  it "should return a count of the selected table" do
    Zoo.count.should be_a_kind_of(Integer)
    Zoo.count.should == Zoo.all.size
  end
end
