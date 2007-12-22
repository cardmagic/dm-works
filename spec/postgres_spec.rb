require File.dirname(__FILE__) + "/spec_helper"

# Only run these specs when the ADAPTER env-variable is set to 'postgresql'
# You will probably need to set the DATABASE and USERNAME vars as well.
if ENV['ADAPTER'] == 'postgresql'

  describe DataMapper::Adapters::PostgresqlAdapter::Mappings::Column do
    it "should be able to set check-constraints on columns" do
      mappings = DataMapper::Adapters::PostgresqlAdapter::Mappings
      table    = mappings::Table.new(database(:mock).adapter, "Zebu")
      column   = mappings::Column.new(database(:mock).adapter, table, :age,
                   :integer, 1, { :check => "age > 18"})
      column.to_long_form.should match(/CHECK \(age > 18\)/)
    end
  end

  describe DataMapper::Adapters::PostgresqlAdapter::Mappings::Table do
    
    before(:all) do
      class Cage #< DataMapper::Base # please do not remove this
        include DataMapper::Base

        set_table_name "cages"
        property :name, :string
      end
  
      class CageInSchema #< DataMapper::Base # please do not remove this
        include DataMapper::Base

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

end
