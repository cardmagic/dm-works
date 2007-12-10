require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Adapters::Sql::Commands::LoadCommand do
  
  def conditions_for(klass, options = {})
    database_context = database(:mock)
    DataMapper::Adapters::Sql::Commands::LoadCommand.new(
      database_context.adapter, database_context, klass, options
    ).conditions
  end
  
  it 'empty? should be false if conditions are present' do
    conditions_for(Zoo, :name => 'Galveston').should_not be_empty
  end
  
  it 'should map implicit option names to field names' do
    conditions_for(Zoo, :name => 'Galveston').should eql([["`name` = ?", 'Galveston']])
  end
  
  it 'should qualify with table name when using a join' do
    conditions_for(Zoo, :name => 'Galveston', :include => :exhibits).should eql([["`zoos`.`name` = ?", 'Galveston']])
  end
  
  it 'should use Symbol::Operator to determine operator' do
    conditions_for(Person, :age.gt => 28).should eql([["`age` > ?", 28]])
    conditions_for(Person, :age.gte => 28).should eql([["`age` >= ?", 28]])
    
    conditions_for(Person, :age.lt => 28).should eql([["`age` < ?", 28]])
    conditions_for(Person, :age.lte => 28).should eql([["`age` <= ?", 28]])
    
    conditions_for(Person, :age.not => 28).should eql([["`age` <> ?", 28]])
    conditions_for(Person, :age.eql => 28).should eql([["`age` = ?", 28]])
    
    conditions_for(Person, :name.like => 'S%').should eql([["`name` LIKE ?", 'S%']])
    
    conditions_for(Person, :age.in => [ 28, 29 ]).should eql([["`age` IN ?", [ 28, 29 ]]])
  end
  
  it 'should use an IN clause for an Array' do
    conditions_for(Person, :age => [ 28, 29 ]).should eql([["`age` IN ?", [ 28, 29 ]]])
  end
  
  it 'should use "not" for not-equal operations' do
    conditions_for(Person, :name.not => 'Bob').should eql([["`name` <> ?", 'Bob']])
    conditions_for(Person, :name.not => nil).should eql([["`name` IS NOT ?", nil]])
    conditions_for(Person, :name.not => ['Sam', 'Bob']).should eql([["`name` NOT IN ?", ['Sam', 'Bob']]])
  end

end