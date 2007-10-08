describe DataMapper::Associations::BelongsToAssociation do
  before(:each) do
    @aviary = Exhibit[:name => 'Monkey Mayhem']
  end
  
  it 'has a zoo association' do
    @aviary.zoo.class.should == Zoo
    Exhibit.new.zoo.should == nil
  end
  
  it 'belongs to a zoo' do
    @aviary.zoo.should == @aviary.session.first(Zoo, :name => 'San Diego')
  end
  
  it "is assigned a zoo_id" do
    zoo = Zoo.first
    exhibit = Exhibit.new(:name => 'bob')
    exhibit.zoo = zoo
    exhibit.instance_variable_get("@zoo_id").should == zoo.id    
  end
  
  it 'can build its zoo' do
    database do |db|
      e = Exhibit.new({:name => 'Super Extra Crazy Monkey Cage'})
      e.zoo.should == nil
      e.build_zoo({:name => 'Monkey Zoo'})
      e.zoo.class == Zoo
      e.zoo.new_record?.should == true
      
      # Need to get associations working properly before this works ....
      e.save
    end
  end
  
  it 'can build its zoo' do
    database do |db|
      e = Exhibit.new({:name => 'Super Extra Crazy Monkey Cage'})
      e.zoo.should == nil
      e.create_zoo({:name => 'Monkey Zoo'})
      e.zoo.class == Zoo
      e.zoo.new_record?.should == false
      e.save
    end
  end
  
  after(:all) do
    fixtures('zoos')
    fixtures('exhibits')
  end
end

describe DataMapper::Associations::HasManyAssociation do
  
  it "should generate the SQL for a join statement" do
    exhibits_association = database(:mock).schema[Zoo].associations.find { |a| a.name == :exhibits }
  
    exhibits_association.to_sql.should == <<-EOS.compress_lines
      JOIN `exhibits` ON `exhibits`.`zoo_id` = `zoos`.`id`
    EOS
  end

end

describe DataMapper::Associations::HasOneAssociation do
  
  it "should generate the SQL for a join statement" do
    fruit_association = database(:mock).schema[Animal].associations.find { |a| a.name == :favourite_fruit }
  
    fruit_association.to_sql.should == <<-EOS.compress_lines
      JOIN `fruit` ON `fruit`.`devourer_id` = `animals`.`id`
    EOS
  end

end

describe DataMapper::Associations::HasAndBelongsToManyAssociation do

  before(:all) do
    fixtures(:animals)
    fixtures(:exhibits)
  end
  
  before(:each) do
    @amazonia = Exhibit[:name => 'Amazonia']
  end
  
  it "should generate the SQL for a join statement" do
    animals_association = database(:mock).schema[Exhibit].associations.find { |a| a.name == :animals }
  
    animals_association.to_sql.should == <<-EOS.compress_lines
      JOIN `animals_exhibits` ON `animals_exhibits`.`exhibit_id` = `exhibits`.`id`
      JOIN `animals` ON `animals`.`id` = `animals_exhibits`.`animal_id`
    EOS
  end
  
  it "should load associations" do
    database do
      froggy = Animal[:name => 'Frog']
      froggy.exhibits.size.should == 1
      froggy.exhibits.entries.first.should == Exhibit[:name => 'Amazonia']
    end
  end
  
  it 'has an animals association' do
    [@amazonia, Exhibit.new].each do |exhibit|
      exhibit.animals.class.should == DataMapper::Associations::HasAndBelongsToManyAssociation::Set
    end
  end
  
  it 'has many animals' do
    @amazonia.animals.size.should == 1
  end
  
  it 'should load associations magically' do
    Exhibit.all.each do |exhibit|
      exhibit.animals.each do |animal|
        animal.exhibits.should include(exhibit)
      end
    end
  end

end