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
    conditions_for(Zoo, :name => 'Galveston', :include => :exhibits).to_parameterized_sql.should == ["`zoos`.`name` = ?", 'Galveston']
  end
  
end