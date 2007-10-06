describe DataMapper::Adapters::Sql::Commands::SaveCommand do
  
  it "should create a new row" do
    total = Zoo.all.length
    Zoo.create({ :name => 'bob' })
    zoo = Zoo[:name => 'bob']
    zoo.name.should == 'bob'
    Zoo.all.length.should == total+1
  end
  
  it "should update an existing row" do
    dallas = Zoo[:name => 'Dallas']
    dallas.name = 'bob'
    dallas.save
    dallas.name = 'Dallas'
    dallas.save
  end
  
  it "should be able to read other attributes after a record is created" do
    zoo = Zoo.create({ :name => 'bob' })
    zoo.notes.should == nil
  end
  
  it "should stamp association on save" do
    database do
      dallas = Zoo[:name => 'Dallas']
      dallas.exhibits << Exhibit.new(:name => 'Flying Monkeys')
      dallas.save
      Exhibit[:name => 'Flying Monkeys'].zoo.should == dallas
    end
  end
  
  it "should be invalid if invalid associations are loaded" do
    miami = Zoo[:name => 'Miami']
    fish_fancy = Exhibit.new
    miami.exhibits << fish_fancy
    miami.should_not be_valid
    fish_fancy.name = 'Fish Fancy'
    fish_fancy.should be_valid
    miami.should be_valid
  end
  
  it "should retrieve it's id on creation if the key is auto-incrementing so it can be successively updated" do
    database do # Use the same Session so the reference-equality checks will pass.
      mary = Animal::create(:name => 'Mary')
      mary.name = 'Jane'
      mary.save.should == true
      jane = Animal.first(:name => 'Jane')
      mary.should == jane
    end
  end
  
end