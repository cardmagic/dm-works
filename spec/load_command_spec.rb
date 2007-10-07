describe DataMapper::Adapters::Sql::Commands::LoadCommand do
  
  before(:all) do
    fixtures(:zoos)
  end
  
  it "should return a Struct for custom queries" do
    results = database.query("SELECT * FROM zoos WHERE name = ?", 'Galveston')
    zoo = results.first
    zoo.class.superclass.should == Struct
    zoo.name.should == "Galveston"
  end
  
end
  
describe DataMapper::Adapters::Sql::Commands::AdvancedLoadCommand do

  before(:all) do
    fixtures(:zoos)
  end
  
  it "should return a Struct for custom queries" do
    results = database.query("SELECT * FROM zoos WHERE name = ?", 'Galveston')
    zoo = results.first
    zoo.class.superclass.should == Struct
    zoo.name.should == "Galveston"
  end
  
  def loader_for(klass, options = {})
    session = database(:mock)
#    p session.adapter
    DataMapper::Adapters::Sql::Commands::AdvancedLoadCommand.new(session.adapter, session, klass, options)
  end

  it "should return a simple select statement for a given class" do
    loader_for(Zoo).to_parameterized_sql.first.should == 'SELECT `id`, `name` FROM `zoos`'
  end

  it "should include only the columns specified in the statement" do
    loader_for(Zoo, :select => [:name]).to_parameterized_sql.first.should == 'SELECT `name` FROM `zoos`'
  end

  it "should optionally include lazy-loaded columns in the statement" do
    loader_for(Zoo, :include => :notes).to_parameterized_sql.first.should == 'SELECT `id`, `name`, `notes` FROM `zoos`'
  end

  it "should join associations in the statement" do
    loader_for(Zoo, :include => :exhibits).to_parameterized_sql.first.should == <<-EOS.compress_lines
      SELECT `zoos`.`id`, `zoos`.`name`,
        `exhibits`.`id`, `exhibits`.`name`, `exhibits`.`zoo_id`
      FROM `zoos`
      JOIN `exhibits` ON `exhibits`.`zoo_id` = `zoos`.`id`
    EOS
  end

  it "should join has and belongs to many associtions in the statement" do
    loader_for(Animal, :include => :exhibits).to_parameterized_sql.first.should == <<-EOS.compress_lines
      SELECT `animals`.`id`, `animals`.`name`,
        `exhibits`.`id`, `exhibits`.`name`, `exhibits`.`zoo_id`,
        `animals_exhibits`.`animal_id`, `animals_exhibits`.`exhibit_id`
      FROM `animals`
      JOIN `animals_exhibits` ON `animals_exhibits`.`animal_id` = `animals`.`id`
      JOIN `exhibits` ON `exhibits`.`id` = `animals_exhibits`.`exhibit_id`
    EOS
  end
  
  it "should shallow-join unmapped tables for has-and-belongs-to-many in the statement" do
    loader_for(Animal, :shallow_include => :exhibits).to_parameterized_sql.first.should == <<-EOS.compress_lines
      SELECT `animals`.`id`, `animals`.`name`,
        `animals_exhibits`.`animal_id`, `animals_exhibits`.`exhibit_id`
      FROM `animals`
      JOIN `animals_exhibits` ON `animals_exhibits`.`animal_id` = `animals`.`id`
    EOS
  end
  
  it "should allow multiple implicit conditions" do
    expected_sql = <<-EOS.compress_lines
      SELECT `id`, `name`, `age`, `occupation`,
        `type`, `street`, `city`, `state`, `zip_code`
      FROM `people`
      WHERE (`name` = ?) AND (`age` = ?)
    EOS
    
    # NOTE: I'm actually not sure how to test this since the order of the parameters isn't gauranteed.
    # Maybe an ugly OrderedHash passed as the options...
    # loader_for(Person, :name => 'Sam', :age => 29).to_parameterized_sql.should == [expected_sql, 'Sam', 29]
  end
  
  it "should allow block-interception during load" do
    result = false
    Person.first(:intercept_load => lambda { result = true })
    result.should == true
  end
  
  it 'database-specific load should not fail' do

     DataMapper::database do |db|
       froggy = db.first(Animal, :conditions => ['name = ?', 'Frog'])
       froggy.name.should == 'Frog'
     end

   end

   it 'current-database load should not fail' do
     froggy = DataMapper::database.first(Animal).name.should == 'Frog'
   end

   it 'load through ActiveRecord impersonation should not fail' do
     Animal.find(:all).size.should == 16
   end

   it 'load through Og impersonation should not fail' do
     Animal.all.size.should == 16
   end

   it ':conditions option should accept a hash' do
     Animal.all(:conditions => { :name => 'Frog' }).size.should == 1
   end

   it 'non-standard options should be considered part of the conditions' do
     database.log.debug('non-standard options should be considered part of the conditions')
     zebra = Animal.first(:name => 'Zebra')
     zebra.name.should == 'Zebra'

     elephant = Animal[:name => 'Elephant']
     elephant.name.should == 'Elephant'

     aged = Person.all(:age => 29)
     aged.size.should == 2
     aged.first.name.should == 'Sam'
     aged.last.name.should == 'Bob'

     fixtures(:animals)
   end

   it 'should not find deleted objects' do
     database do
       wally = Animal[:name => 'Whale']
       wally.new_record?.should == false
       wally.destroy!.should == true

       wallys_evil_twin = Animal[:name => 'Whale']
       wallys_evil_twin.should == nil

       wally.new_record?.should == true
       wally.save
       wally.new_record?.should == false

       Animal[:name => 'Whale'].should == wally
     end
   end

   it 'lazy-loads should issue for whole sets' do
     people = Person.all

     people.each do |person|
       person.notes
     end
   end

end

=begin
context 'Sub-selection' do
  
  specify 'should return a Cup' do
    Animal[:id.select => { :name => 'cup' }].name.should == 'Cup'
  end
  
  specify 'should return all exhibits for Galveston zoo' do
    Exhibit.all(:zoo_id.select(Zoo) => { :name => 'Galveston' }).size.should == 3
  end
  
  specify 'should allow a sub-select in the select-list' do
    Animal[:select => [ :id.count ]]
  end
end
=end