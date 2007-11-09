describe DataMapper::Property do
  
  before(:all) do
    @property = Zoo.properties.find { |property| property.name == :notes }
  end
  
  it "should map a column" do
    @property.column.should eql(database.table(Zoo)[:notes])
  end
  
  it "should determine lazyness" do
    @property.should be_lazy
  end
  
  it "should determine protection level"
  
  it "should return instance variable name"
  
  it "should add a validates_presence_of for not-null properties"
  
  it "should add a validates_format_of if you pass a format option"
end