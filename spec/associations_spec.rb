require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Associations::BelongsToAssociation do
  before(:all) do
    fixtures(:zoos)
  end
  
  before(:each) do
    @aviary = Exhibit[:name => 'Monkey Mayhem']
  end
  
  it 'has a zoo association' do
    @aviary.zoo.class.should == Zoo
    Exhibit.new.zoo.should == nil
  end
  
  it 'belongs to a zoo' do
    @aviary.zoo.should == @aviary.database_context.first(Zoo, :name => 'San Diego')
  end
  
  it "is assigned a zoo_id" do
    zoo = Zoo.first
    exhibit = Exhibit.new(:name => 'bob')
    exhibit.zoo = zoo
    exhibit.instance_variable_get("@zoo_id").should == zoo.id
    
    exhibit.save.should eql(true)
    
    zoo2 = Zoo.first
    zoo2.exhibits.should include(exhibit)
    
    exhibit.destroy!
    
    zoo = Zoo.new(:name => 'bob')
    bob = Exhibit.new(:name => 'bob')
    zoo.exhibits << bob
    zoo.save.should eql(true)
    
    zoo.exhibits.first.should_not be_a_new_record
    
    bob.destroy!
    zoo.destroy!
  end
  
  it 'can build its zoo' do
    database do |db|
      e = Exhibit.new({:name => 'Super Extra Crazy Monkey Cage'})
      e.zoo.should == nil
      e.build_zoo({:name => 'Monkey Zoo'})
      e.zoo.class == Zoo
      e.zoo.new_record?.should == true
      
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
  
  before(:all) do
    fixtures(:zoos)
    fixtures(:exhibits)
  end

  before(:each) do
    @zoo = Zoo.new(:name => "ZOO")
    @zoo.save 
  end
  
  after(:each) do
    @zoo.destroy!
  end
  
  it "should return an empty Enumerable for new objects" do
    project = Project.new
    project.sections.should be_a_kind_of(Enumerable)
    project.sections.should be_empty
  end
  
  it "should display correctly when inspected" do
    Zoo.first(:name => 'Dallas').exhibits.inspect.should match(/\#\<Exhibit\:0x.{7}/)
  end
  
  it 'should lazily-load the association when Enumerable methods are called' do
    database do |db|
      san_diego = Zoo[:name => 'San Diego']
      san_diego.exhibits.size.should == 2
      san_diego.exhibits.should include(Exhibit[:name => 'Monkey Mayhem'])
    end
  end
  
  it 'should eager-load associations for an entire set' do
    database do
      zoos = Zoo.all
      zoos.each do |zoo|
        zoo.exhibits.each do |exhibit|
          exhibit.zoo.should == zoo
        end
      end
    end
  end
  
  it "should be dirty even when clean objects are associated" do
    zoo = Zoo[:name => 'New York']
    zoo.exhibits << Exhibit.first
    zoo.should be_dirty
  end
  
  it "should proxy associations on the associated type" do
    Zoo[:name => 'Miami'].exhibits.animals.size.should == 1
  end
  
  it "should have a valid zoo setup for testing" do
    @zoo.should be_valid
    @zoo.should_not be_a_new_record
    @zoo.id.should_not be_nil
  end  
  
  it "should generate the SQL for a join statement" do
    exhibits_association = database(:mock).schema[Zoo].associations.find { |a| a.name == :exhibits }
  
    exhibits_association.to_sql.should == <<-EOS.compress_lines
      JOIN `exhibits` ON `exhibits`.`zoo_id` = `zoos`.`id`
    EOS
  end

  it "should add an item to an association" do
    bear = Exhibit.new( :name => "Bear")
    @zoo.exhibits << bear
    @zoo.exhibits.should include(bear)
  end
  
  it "should build a new item" do
    bear = @zoo.exhibits.build( :name => "Bear" )
    bear.should be_kind_of(Exhibit)
    @zoo.exhibits.should include(bear)
  end

  it "should not save the item when building" do
    bear = @zoo.exhibits.build( :name => "Bear" )
    bear.should be_new_record
  end
  
  it "should create a new item" do
    bear = @zoo.exhibits.create( :name => "Bear" )
    bear.should be_kind_of(Exhibit)
    @zoo.exhibits.should include(bear)
  end

  it "should save the item when creating" do
    bear = @zoo.exhibits.create( :name => "Bear" )
    bear.should_not be_new_record
  end

  it "should set the association to a saved target when added with <<" do    
    pirahna = Exhibit.new(:name => "Pirahna")
    pirahna.zoo_id.should be_nil
    
    @zoo.exhibits << pirahna
    pirahna.zoo.should == @zoo
  end
  
  it "should set the association to a non-saved target when added with <<" do
    zoo = Zoo.new(:name => "My Zoo")
    kangaroo = Exhibit.new(:name => "Kangaroo")
    zoo.exhibits << kangaroo
    kangaroo.zoo.should == zoo
  end
  
  it "should set the id of the exhibit when the associated zoo is saved" do
    snake = Exhibit.new(:name => "Snake")
    @zoo.exhibits << snake
    @zoo.save
    @zoo.id.should == snake.zoo_id
  end
  
  it "should set the id of an already saved exibit if it's added to a different zoo" do
    beaver = Exhibit.new(:name => "Beaver")
    beaver.save
    beaver.should_not be_a_new_record
    @zoo.exhibits << beaver
    @zoo.save
    beaver.zoo.should == @zoo
    beaver.zoo_id.should == @zoo.id    
  end
  
  it "should set the size of the assocation" do
    @zoo.exhibits << Exhibit.new(:name => "anonymous")
    @zoo.exhibits.size.should == 1
  end
  
  it "should give the association when an inspect is done on it" do
    whale = Exhibit.new(:name => "Whale")
    @zoo.exhibits << whale
    @zoo.exhibits.should_not == "nil"
    @zoo.exhibits.inspect.should_not be_nil
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
  
  it 'should allow association of additional objects' do
    @amazonia.animals << Animal.new(:name => "Buffalo")
    @amazonia.animals.size.should == 2
    @amazonia.reload
  end
  
  it 'should allow you to fill and clear an association' do
    marcy = Exhibit.create(:name => 'marcy')
    
    Animal.all.each do |animal|
      marcy.animals << animal
    end
    
    marcy.save.should eql(true)
    marcy.should have(Animal.count).animals
    
    marcy.animals.clear
    marcy.should have(0).animals
    
    marcy.save.should eql(true)
    
    marcys_stand_in = Exhibit[marcy.id]
    marcys_stand_in.should have(0).animals
    
    marcy.destroy!    
  end
  
  it 'should allow you to delete a specific association member' do
    walter = Exhibit.create(:name => 'walter')

    Animal.all.each do |animal|
      walter.animals << animal
    end
    
    walter.save.should eql(true)
    walter.should have(Animal.count).animals
    
    delete_me = walter.animals.entries.first
    walter.animals.delete(delete_me).should eql(delete_me)
    walter.animals.delete(delete_me).should eql(nil)
    
    walter.should have(Animal.count - 1).animals
    walter.save.should eql(true)
    
    walters_stand_in = Exhibit[walter.id]
    walters_stand_in.animals.size.should eql(walter.animals.size)

    walter.destroy!
  end
  
  it "should allow updates to associations using association_ids[]" do
    pending "Awaiting implementation of association_ids[]"
    meerkat = Animal.new(:name => "Meerkat")
    @amazonia.animals.size.should == 1
    
    @amazonia.animal_ids << meerkat.id
    @amazonia.save
    
    @amazonia.animals.size.should == 2
    @amazonia.animals.should include?(meerkat)
  end
  
  it "Should handle setting complementary associations" do
    u1 = User.create(:name => "u1")
    u1.comments.should be_empty
    
    c1 = Comment.create(:comment => "c", :author => u1)
    p u1
    p c1
    
    u1.comments.should_not be_empty
    u1.comments.should include(c1)
    
    u1.reload!
    u1.comments.should_not be_empty
    u1.comments.should include(c1)
  end

end
