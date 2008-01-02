require File.dirname(__FILE__) + '/spec_helper'

describe DataMapper::Property do
  
  before(:all) do
    @property = Zoo.properties.find { |property| property.name == :notes }
  end
  
  it "should map a column" do
    @property.column.should eql(database.table(Zoo)[:notes])
  end
  
  it "should determine lazyness" do
    @property.should be_lazy
  end
  
  it "should determine protection level" do
    @property.reader_visibility.should == :public
    @property.writer_visibility.should == :public
  end
  
  it "should return instance variable name" do
    @property.instance_variable_name.should == database.table(Zoo)[:notes].instance_variable_name
  end
  
  it "should add a validates_presence_of for not-null properties" do
    zoo = Zoo.new
    zoo.valid?.should == false
    zoo.name = "Content"
    zoo.valid?.should == true
  end
  
  it "should add a validates_format_of if you pass a format option"
end

describe DataMapper::Adapters::Sql::Mappings do
  
  it "should return the same Table instance for two objects mapped to the same database table" do
    # Refers to the same Table instance
    database.table(Person) == database.table(SalesPerson)
  end
  
  it "should have one super-set of total mapped columns" do
    # Refers to the mapped columns
    database.table(Person).columns == database.table(SalesPerson).columns
  end
  
  it "should have one set of columns that represents the actual database" do
    # Refers to the actual columns in the database, which may/are-likely-to-be different
    # than the mapped columns, sometimes just because your models are dealing with
    # a legacy database where not every column is mapped to the new model, so this
    # is expected.
    database.table(Person).send(:database_columns) == database.table(SalesPerson).send(:database_columns)
  end
  
  it "should have two different sets of mapped properties that point to subsets of the Table columns" do
    pending("This one still needs some love to pass.")
    table = database.table(Person)
    
    # Every property's column should be represented in the Table's column mappings.
    Person.properties.each do |property|
      table.columns.should include(property.column)
    end
    
    # For both models in the STI setup...
    SalesPerson.properties.each do |property|
      table.columns.should include(property.column)
    end
    
    # Even though Person's properties are fewer than a SalesPerson's
    Person.properties.size.should_not eql(SalesPerson.properties.size)
    
    # And Person's properties should be a subset of a SalesPerson's
    Person.properties.each do |property|
      SalesPerson.properties.map(&:column).should include(property.column)
    end
  end
  
end