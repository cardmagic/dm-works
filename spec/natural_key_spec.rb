require File.dirname(__FILE__) + "/spec_helper"

describe('A Natural Key') do
  
  it "should cause the Table to return a default foreign key composed of it's table and key column name" do
    database.table(Person).default_foreign_key.should eql('person_id')
    database.table(Career).default_foreign_key.should eql('career_name')
  end
  
end