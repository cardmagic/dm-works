describe DataMapper::Adapters::Sql::Commands::CountCommand do
    
  before(:all) do
    fixtures(:zoos)
  end

  
  it "should be condition" do
    session = database(:mock)
    DataMapper::Adapters::Sql::Commands::CountCommand.new(session.adapter, Zoo).to_sql.should == "SELECT COUNT(*) AS row_count FROM `zoos`"
  end

  it "should return a count of the selected table" do
    Zoo.count.should be_a_kind_of(Integer)
    Zoo.count.should == Zoo.all.size
  end
end
