describe "Magic Columns" do
  
  it "should update updated_at on save" do
    zoo = Zoo.new(:name => 'Mary')
    zoo.save
    zoo.updated_at.should be_a_kind_of(Time)
  end
  
end