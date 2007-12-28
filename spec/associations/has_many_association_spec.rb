require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Associations::HasManyAssociation do
  
  before(:all) do
    fixtures(:zoos)
    fixtures(:exhibits)
    fixtures(:fruit)
    fixtures(:animals)
  end

  after(:all) do
    fixtures(:fruit)
    fixtures(:animals)
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
    project.sections.should be_nil
  end
  
  it "should display correctly when inspected" do
    Zoo.first(:name => 'Dallas').exhibits.inspect.should match(/\#\<Exhibit\:0x.{7}/)
  end
  
  it 'should lazily-load the association when Enumerable methods are called' do
    database do |db|
      san_diego = Zoo.first(:name => 'San Diego')
      san_diego.exhibits.size.should == 2
      san_diego.exhibits.should include(Exhibit.first(:name => 'Monkey Mayhem'))
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
    zoo = Zoo.first(:name => 'New York')
    zoo.exhibits << Exhibit.first
    zoo.should be_dirty
  end
  
  it "should proxy associations on the associated type" do
    Zoo.first(:name => 'Miami').exhibits.animals.size.should == 1
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
  
  it "should generate the SQL for a join statement" do
    fruit_association = database(:mock).schema[Animal].associations.find { |a| a.name == :favourite_fruit }
  
    fruit_association.to_sql.should == <<-EOS.compress_lines
      JOIN `fruit` ON `fruit`.`devourer_id` = `animals`.`id`
    EOS
  end

  it "is assigned a devourer_id" do
    bob = Animal.new(:name => 'bob')
    fruit = Fruit.first
    bob.favourite_fruit = fruit
    
    bob.save
    
    bob.reload!
    fruit.devourer_id.should eql(bob.id)
    bob.favourite_fruit.should == fruit
    
    fruit.reload!
    fruit.devourer_of_souls.should == bob
  end
  
  it "Should handle setting complementary associations" do
    pending "http://wm.lighthouseapp.com/projects/4819/tickets/84-belongs_to-associations-not-working-for-me"
    u1 = User.create(:name => "u1")
    u1.comments.should be_empty
    
    c1 = Comment.create(:comment => "c", :author => u1)
    # p u1
    # p c1
    
    u1.comments.should_not be_empty
    u1.comments.should include(c1)
    
    u1.reload!
    u1.comments.should_not be_empty
    u1.comments.should include(c1)
  end
  
  it "should allow updates to associations using association_keys=" do
    # pending "http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/109-associations-should-support-association_keys-methods"
    database(:default) do
      london = Zoo.create(:name => "London")
      dunes = Exhibit.create(:name => "Dunes")
      
      london.exhibits.should be_empty
      london.send(:exhibits_keys=, dunes.id)
      london.save.should be_true
    
      london.should have(1).exhibits
      london.exhibits.should include(dunes)
      
      london.reload!
      london.should have(1).exhibits
      
      london.destroy!
      dunes.destroy!
    end
  end
end
