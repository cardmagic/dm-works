require File.dirname(__FILE__) + "/spec_helper"

# * you have some crazy finder options... ie: Zoo, :name => 'bob', :include => :exhibits
# 
# * you want to turn this into SQL.
# 
# * you want to execute this SQL...
# 
# * you want to load objects from the results, which means you have to know what columns in the results map to what objects
# 
# * some values in the results will have no corresponding objects, theyll be indicators of other behaviour that should take place
#   ie: the values for a m:n join table will tell you how to bind the associated objects together, or...
#     the :type column will tell you what type to instantiate    
#
#
# So... the QueryBuilder class should basically take the options from step 1, give you the SQL in step 2,
# allow you to handle step 3, and expose types/result-set mappings to load objects by for step 4.
# step 5 should be handled in the DataObjectAdapter
describe DataMapper::Query do
  
  it "should return the primary table for a simple query, along with the conditions" do
    query = DataMapper::Query.new(database(:mock).adapter, Zoo, :name => 'bob')
    query.to_sql.should == "SELECT `id`, `name`, `updated_at` FROM `zoos` WHERE (`name` = ?)"
    query.parameters.should == ['bob']
    
    query = DataMapper::Query.new(database(:mock).adapter, Animal, :name => 'bob')
    query.to_sql.should == "SELECT `id`, `name`, `nice` FROM `animals` WHERE (`name` = ?)"
    query.parameters.should == ['bob']
    
    query = DataMapper::Query.new(database(:mock).adapter, Project)
    query.to_sql.should == "SELECT `id`, `title`, `description`, `deleted_at` FROM `projects` WHERE (`deleted_at` IS NULL OR `deleted_at` > NOW())"
    query.parameters.should be_empty
  end
  
end