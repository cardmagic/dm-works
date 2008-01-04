require File.dirname(__FILE__) + "/spec_helper"
require File.dirname(__FILE__) + "/../lib/data_mapper/migration"

class MigrationUser
  include DataMapper::Persistence
  
  property :name, :string
  property :login, :string
  
end

class AddUsers < DataMapper::Migration
  def self.up
    table :migration_users do # sees that the users table does not exist and so creates the table
      add :name, :string
      add :login, :string
    end
  end

  def self.down
    table.drop :migration_users
  end
end

class AddPasswordToUsers < DataMapper::Migration
  def self.up
    table :migration_users do
      add :password, :string
    end
  end
  
  def self.down
    table :migration_users do
      remove :password
    end
  end
end

class RailsAddUsers < DataMapper::Migration
  def self.up
    create_table :migration_users do |t|
      t.column :name, :string
      t.column :login, :string
    end
  end
  
  def self.down
    drop_table :migration_users
  end
end

class RailsAddPasswordToUsers < DataMapper::Migration
  def self.up
    add_column :migration_users, :password, :string
  end
  
  def self.down
    remove_column :migration_users, :password
  end
end

def check_schema
  database.query("
  SELECT sql FROM
     (SELECT * FROM sqlite_master UNION ALL
      SELECT * FROM sqlite_temp_master)
  WHERE name = 'migration_users'
  ORDER BY substr(type,2,1), name
  ")[0]
end

describe DataMapper::Migration do
  it "should migrate up creating a table with its columns" do
    AddUsers.migrate(:up)
    database.table_exists?(MigrationUser).should == true
    check_schema.match(/migration_users/).should be_a_kind_of(MatchData)
    check_schema.match(/name|login/).should be_a_kind_of(MatchData)
    user = MigrationUser.new(:name => "test", :login => "username")
    user.save.should == true
    MigrationUser.first.should == user
  end
  
  it "should migrate down deleting the created table" do
    AddUsers.migrate(:down)
    check_schema.should == nil
    database.table_exists?(MigrationUser).should == false
  end
  
  it "should migrate up altering a table to add a column" do
    AddUsers.migrate(:up)
    AddPasswordToUsers.migrate(:up)
    table = database.table(MigrationUser)
    table[:password].should_not == nil
  end
  
  it "should migrate down altering a table to remove a column" do
    check_schema.match(/password/).should be_a_kind_of(MatchData)
    AddPasswordToUsers.migrate(:down)
    check_schema.match(/password/).should == nil
    table = database.table(MigrationUser)
    table[:password].should == nil
    AddUsers.migrate(:down)
  end
  
  it "should migrate up creating a table with its columns [RAILS]" do
    RailsAddUsers.migrate(:up)
    database.table_exists?(MigrationUser).should == true
    check_schema.match(/migration_users/).should be_a_kind_of(MatchData)
    check_schema.match(/name|login/).should be_a_kind_of(MatchData)
  end
  
  it "should migrate down deleting the created table [RAILS]" do
    RailsAddUsers.migrate(:down)
    database.table_exists?(MigrationUser).should == false
    check_schema.should == nil
  end
  
  it "should migrate up altering a table to add a column [RAILS]" do
    RailsAddUsers.migrate(:up)
    RailsAddPasswordToUsers.migrate(:up)
    check_schema.match(/password/).should be_a_kind_of(MatchData)
  end
  
  it "should migrate down altering a table to remove a column [RAILS]" do
    RailsAddPasswordToUsers.migrate(:down)
    check_schema.match(/password/).should == nil
    table = database.table(MigrationUser)
    table[:password].should == nil
    RailsAddUsers.migrate(:down)
  end
end