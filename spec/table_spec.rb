require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Adapters::Sql::Mappings::Table do
  it "should return all columns from the database" do
    table = database.adapter.schema.database_tables.detect{|table| table.name == "zoos"}
    columns = table.database_columns
    columns.size.should == database.schema[Zoo].columns.size
    columns.each { |column| column.should be_a_kind_of( DataMapper::Adapters::Sql::Mappings::Column ) }
  end
  
  it "should return the default for a column from the database" do
    table = database.adapter.schema.database_tables.detect{|table| table.name == "animals"}
    columns = table.database_columns
    
    column1 = columns.detect{|column| column.name == :name }
    column1.default.should == "No Name"
    
    column2 = columns.detect{|column| column.name == :nice }
    column2.default.should == nil
  end
  
  it "should return the nullability for a column from the database" do
    table = database.adapter.schema.database_tables.detect{|table| table.name == "animals"}
    columns = table.database_columns
    
    column1 = columns.detect{|column| column.name == :id }
    column1.nullable?.should be_false
    
    column2 = columns.detect{|column| column.name == :nice }
    column2.nullable?.should be_true
  end
  
end
