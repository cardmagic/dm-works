require File.dirname(__FILE__) + "/spec_helper"

describe Zoo, "with auto-migrations" do
  it "should allow auto migration" do
    Zoo.should respond_to("auto_migrate!")
  end
end

describe DataMapper::AutoMigrations do
  it "should find all new models" do
    database.schema[Zoo].drop!
    Zoo.auto_migrate!
    database.table_exists?(Zoo).should be_true
    database.column_exists_for_table?(Zoo, :id).should be_true
    database.column_exists_for_table?(Zoo, :name).should be_true
    database.column_exists_for_table?(Zoo, :notes).should be_true
    database.column_exists_for_table?(Zoo, :updated_at).should be_true    
  end
  
  it "should find all changed models"
  it "should find all unmapped tables"
end

describe DataMapper::AutoMigrations, "when migrating a new model" do
  it "should allow creation of new tables for new models"
  it "should allow renaming of unmapped tables for new models"
  it "should create columns for the model's properties"
end

describe DataMapper::AutoMigrations, "when migrating a changed model" do
  it "should find all new properties"
  it "should allow creation of new columns for new properties"
  it "should allow an unmapped column to be renamed for a new property"
  it "should find all unmapped columns"
  it "should allow removal of any or all unmapped columns"
end

describe DataMapper::AutoMigrations, "when migrating an unmapped table" do
  it "should allow the table to be dropped"
end

describe DataMapper::AutoMigrations, "after migrating" do
  it "should store migration decisions to allow the migration to be replicated"
end
