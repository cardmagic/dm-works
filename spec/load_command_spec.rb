describe DataMapper::Adapters::Sql::Commands::LoadCommand do
  
  before(:all) do
    fixtures(:zoos)
  end
  
  it "should return a Struct for custom queries" do
    results = database.query("SELECT * FROM zoos WHERE name = ?", 'Galveston')
    zoo = results.first
    zoo.class.superclass.should == DataMapper::Support::Struct
    zoo.name.should == "Galveston"
  end
  
end

return unless ENV['ADAPTER'].nil? || ENV['ADAPTER'] == 'mysql'
  
describe DataMapper::Adapters::Sql::Commands::AdvancedLoadCommand do

  def loader_for(klass, options = {})
    session = database
    DataMapper::Adapters::Sql::Commands::AdvancedLoadCommand.new(session.adapter, session, klass, options)
  end

  it "should return a simple select statement for a given class" do
    loader_for(Zoo).to_sql.should == 'SELECT `id`, `name` FROM `zoos`'
  end

  it "should include only the columns specified in the statement" do
    loader_for(Zoo, :select => [:name]).to_sql.should == 'SELECT `name` FROM `zoos`'
  end

  it "should optionally include lazy-loaded columns in the statement" do
    loader_for(Zoo, :include => :notes).to_sql.should == 'SELECT `id`, `name`, `notes` FROM `zoos`'
  end

  it "should join associations in the statement" do
    loader_for(Zoo, :include => :exhibits).to_sql.should == <<-EOS.compress_lines
      SELECT `zoos`.`id`, `zoos`.`name`,
        `exhibits`.`id`, `exhibits`.`name`, `exhibits`.`zoo_id`
      FROM `zoos`
      JOIN `exhibits` ON `exhibits`.`zoo_id` = `zoos`.`id`
    EOS
  end

  it "should join has and belongs to many associtions in the statement" do
    loader_for(Animal, :include => :exhibits).to_sql.should == <<-EOS.compress_lines
      SELECT `animals`.`id`, `animals`.`name`,
        `exhibits`.`id`, `exhibits`.`name`, `exhibits`.`zoo_id`,
        `animals_exhibits`.`animal_id`, `animals_exhibits`.`exhibit_id`
      FROM `animals`
      JOIN `animals_exhibits` ON `animals_exhibits`.`animal_id` = `animals`.`id`
      JOIN `exhibits` ON `exhibits`.`id` = `animals_exhibits`.`exhibit_id`
    EOS
  end
  
  it "should shallow-join unmapped tables for has-and-belongs-to-many in the statement" do
    loader_for(Animal, :shallow_include => :exhibits).to_sql.should == <<-EOS.compress_lines
      SELECT `animals`.`id`, `animals`.`name`,
        `animals_exhibits`.`animal_id`, `animals_exhibits`.`exhibit_id`
      FROM `animals`
      JOIN `animals_exhibits` ON `animals_exhibits`.`animal_id` = `animals`.`id`
    EOS
  end

end