describe DataMapper::Support do
  
  it "a String should translate" do
    "%s is great!".t('DataMapper').should eql("DataMapper is great!")
  end
  
end