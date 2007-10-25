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
  
  it 'should cast to a Date' do
    target = Date.civil(2001, 1, 1)
    
    @coersive.type_cast_date('2001-1-1').should eql(target)
    @coersive.type_cast_date(target.dup).should eql(target)
    @coersive.type_cast_date(DateTime::parse('2001-1-1')).should eql(target)
    @coersive.type_cast_date(Time::parse('2001-1-1')).should eql(target)
  end
  
end