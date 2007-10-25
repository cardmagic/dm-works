describe DataMapper::Adapters::Sql::Coersion do
  
  before(:all) do
    @coersive = Class.new do
      include DataMapper::Adapters::Sql::Coersion
    end.new
  end
  
  it 'should cast to a BigDecimal' do
    target = BigDecimal.new('7.2')
    @coersive.type_cast_decimal('7.2').should == target
    @coersive.type_cast_decimal(7.2).should == target
  end
  
  it 'should store and load a date' do
    dob = Date::today
    bob = Person.create(:name => 'DateCoersionTest', :date_of_birth => dob)
    
    bob2 = Person[:name => 'DateCoersionTest']
    
    bob.date_of_birth.should eql(dob)
    bob.date_of_birth.should eql(bob2.date_of_birth)
  end
  
end