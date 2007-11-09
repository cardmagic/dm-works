require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Adapters::Sql::Mappings::Table do
  it "should return all columns from the database" do
    table = database.adapter.schema.database_tables.detect{|table| table.name == "zoos"}
    columns = table.database_columns
    columns.size.should == database.schema[Zoo].columns.size
    columns.each { |column| column.should be_a_kind_of( DataMapper::Adapters::Sql::Mappings::Column ) }
  end
end
