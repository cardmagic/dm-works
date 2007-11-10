require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Adapters::Sql::Mappings::Column do
  
  before(:all) do
    fixtures(:zoos)
  end
  
  it "should be unique within a set" do
    
    mappings = DataMapper::Adapters::Sql::Mappings
    
    columns = SortedSet.new

    columns << mappings::Column.new(database(:mock).adapter, nil, :one, :string, 1)
    columns << mappings::Column.new(database(:mock).adapter, nil, :two, :string, 2)
    columns << mappings::Column.new(database(:mock).adapter, nil, :three, :string, 3)
    columns.should have(3).entries
    
    columns << mappings::Column.new(database(:mock).adapter, nil, :two, :integer, 3)
    columns.should have(3).entries
    
    columns << mappings::Column.new(database(:mock).adapter, nil, :id, :integer, -1)
    columns.should have(4).entries
  end
  
  it "should get its meta data from the database"
  
  it "should be able to rename" do
#    pending("until drop and alter are specced")
    table = database.table(Zoo)
    name_column = table[:name]
    
    lambda { database.query("SELECT name FROM zoos") }.should_not raise_error
    lambda { database.query("SELECT moo FROM zoos") }.should raise_error
    
    name_column.rename!(:moo).should eql(true)
    name_column.name.should eql(:moo)
    
    lambda { database.query("SELECT name FROM zoos") }.should raise_error
    lambda { database.query("SELECT moo FROM zoos") }.should_not raise_error
    
    name_column.rename!(:name)
    name_column.name.should eql(:name)
    
    lambda { database.query("SELECT name FROM zoos") }.should_not raise_error
    lambda { database.query("SELECT moo FROM zoos") }.should raise_error
  end
  
  it "should create, alter and drop a column" do
    lambda { database.query("SELECT moo FROM zoos") }.should raise_error
    
    table = database.table(Zoo)
    Zoo.property(:moo, :string)
    moo = table[:moo]
    moo.create!
    
    lambda { database.query("SELECT moo FROM zoos") }.should_not raise_error
    
    zoo = Zoo.create(:name => 'columns', :moo => 'AAA')
    zoo.moo.should eql('AAA')
    
    zoo.moo = 4
    zoo.save
    zoo.reload!
    zoo.moo.should eql('4')
    
    moo.type = :integer
    moo.alter!
    zoo.reload!
    zoo.moo.should eql(4)
    
    database.logger.debug { 'MOO' * 10 }
    moo.drop!
    database.logger.debug { 'MOO' * 10 }
    
    lambda { database.query("SELECT moo FROM zoos") }.should raise_error
  end
  
end