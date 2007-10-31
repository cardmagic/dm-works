require File.dirname(__FILE__) + "/spec_helper"

if ENV['ADAPTER'] == 'postgresql' && false
  
  describe DataMapper::Adapters::PostgresqlAdapter::Mappings::Table do
    
    before(:all) do
      class Cage < DataMapper::Base
        set_table_name "cages"
        property :name, :string
      end
  
      class CageInSchema < DataMapper::Base
        set_table_name "my_schema.cages"
        property :name, :string
      end
    end
    
    it "should return a quoted table name for a simple table" do
      table_sql = database.adapter.table(Cage).to_sql
      table_sql.should == "\"cages\""
    end
  
    it "should return a quoted schema and table name for a table which specifies a schema" do
      table_sql = database.adapter.table(CageInSchema).to_sql
      table_sql.should == "\"my_schema\".\"cages\""
    end

    it "should search only the specified schema if qualified" do
      database.save(Cage)
      database.adapter.table(CageInSchema).exists?.should == false
      database.save(CageInSchema)
      database.adapter.table(CageInSchema).exists?.should == true
    end
    
    after do
      database.adapter.execute("DROP SCHEMA my_schema CASCADE") rescue nil
    end
    
  end
  
  describe DataMapper::Adapters::PostgresqlAdapter::Commands::SaveCommand do
    
    before(:all) do
      class Cage < DataMapper::Base
        set_table_name "cages"
        property :name, :string
      end
  
      class CageInSchema < DataMapper::Base
        set_table_name "my_schema.cages"
        property :name, :string
      end
    end
    
    def table_mapping_for(klass)
      session = database
      DataMapper::Adapters::PostgresqlAdapter::Commands::SaveCommand.new(session.adapter, session, klass)
    end
  
    it "should create a schema if it doesn't already exist" do
      create_sql  = table_mapping_for(CageInSchema).to_create_table_sql
      create_sql.should == <<-EOS.compress_lines
      CREATE SCHEMA "my_schema"; CREATE TABLE "my_schema"."cages" ("id" serial primary key, "name" varchar)
      EOS
    end

    it "shouldn't create a schema if it exists" do
      database.save(CageInSchema)
      create_sql  = table_mapping_for(CageInSchema).to_create_table_sql
      create_sql.should == <<-EOS.compress_lines
      CREATE TABLE "my_schema"."cages" ("id" serial primary key, "name" varchar)
      EOS
    end
    
    it "basic crud should work in schemas" do
      database.save(CageInSchema)
      CageInSchema.find(:all).size.should == 0
      CageInSchema.create({ :name => 'bob' })
      CageInSchema.find(:all).size.should == 1
      cage = CageInSchema.first(:name => 'bob')
      cage.name.should == 'bob'
      cage.destroy!.should == true
    end
    
    after do
      database.adapter.execute("DROP SCHEMA my_schema CASCADE") rescue nil
    end
    
  end
end
