describe DataMapper::Adapters::Sql::Commands::Conditions do
  
  def conditions_for(klass, options = {})
    session = database
    DataMapper::Adapters::Sql::Commands::AdvancedLoadCommand.new(
      session.adapter, session, klass, options
    ).conditions
  end
  
  it 'empty? should be false if conditions are present' do
    conditions_for(Zoo, :name => 'Galveston').empty?.should == false
  end
  
  it 'should map implicit option names to field names' do
    conditions_for(Zoo, :name => 'Galveston').to_parameterized_sql.should == ["`name` = ?", 'Galveston']
  end
  
  it 'should qualify with table name when using a join' do
    conditions = conditions_for(Zoo, :name => 'Galveston', :include => :exhibits)
    conditions.to_parameterized_sql.should == ["`zoos`.`name` = ?", 'Galveston']
  end
  
  it 'should use Symbol::Operator to determine operator' do
    conditions_for(Person, :age.gt => 28).to_parameterized_sql.should == ["`age` > ?", 28]
    conditions_for(Person, :age.gte => 28).to_parameterized_sql.should == ["`age` >= ?", 28]
    
    conditions_for(Person, :age.lt => 28).to_parameterized_sql.should == ["`age` < ?", 28]
    conditions_for(Person, :age.lte => 28).to_parameterized_sql.should == ["`age` <= ?", 28]
    
    conditions_for(Person, :age.not => 28).to_parameterized_sql.should == ["`age` <> ?", 28]
    conditions_for(Person, :age.eql => 28).to_parameterized_sql.should == ["`age` = ?", 28]
    
    conditions_for(Person, :name.like => 'S%').to_parameterized_sql.should == ["`name` LIKE ?", 'S%']
    
    conditions_for(Person, :age.in => [ 28, 29 ]).to_parameterized_sql.should == ["`age` IN ?", [ 28, 29 ]]
  end
  
  it 'should use an IN clause for an Array' do
    conditions = conditions_for(Person, :age => [ 28, 29 ])
    conditions.to_parameterized_sql.should == ["`age` IN ?", [ 28, 29 ]]
  end
  
  it 'should use "not" for not-equal operations' do
    conditions_for(Person, :name.not => 'Bob').to_parameterized_sql.should == ["`name` <> ?", 'Bob']
    conditions_for(Person, :name.not => nil).to_parameterized_sql.should == ["`name` IS NOT ?", nil]
    conditions_for(Person, :name.not => ['Sam', 'Bob']).to_parameterized_sql.should == ["`name` NOT IN ?", ['Sam', 'Bob']]
  end

end