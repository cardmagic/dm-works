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
  
  it "should create sql for composite unique indexes" do
    class Cage < DataMapper::Base
      property :name, :string
      property :cage_id, :integer
      
      index [:name, :cage_id], :unique => true
    end
    
    table_sql = database.adapter.table(Cage).to_create_sql
    table_sql.should match(/CREATE UNIQUE INDEX cages_name_cage_id_index/)
  end
  
  it "should create sql for composite indexes" do
    class Lion < DataMapper::Base
      property :name, :string
      property :tamer_id, :integer
      
      index [:name, :tamer_id]
    end
    
    table_sql = database.adapter.table(Lion).to_create_sql
    table_sql.should match(/CREATE INDEX lions_name_tamer_id_index/)
  end
end
