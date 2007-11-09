require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Adapters::Sql::Mappings::Column do
  
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
  
end