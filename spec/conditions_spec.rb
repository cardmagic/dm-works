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
    conditions_for(Zoo, :name => 'Galveston').to_sql.should == "`name` = 'Galveston'"
  end
  
end