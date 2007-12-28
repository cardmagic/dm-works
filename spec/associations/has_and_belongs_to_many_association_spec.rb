require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Associations::HasAndBelongsToManyAssociation do

  before(:all) do
    fixtures(:animals)
    fixtures(:exhibits)
  end
  
  before(:each) do
    @amazonia = Exhibit.first :name => 'Amazonia'
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
      froggy = Animal.first(:name => 'Frog')
      froggy.exhibits.size.should == 1
      froggy.exhibits.first.should == Exhibit.first(:name => 'Amazonia')
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
  
  it "should allow association of additional objects (CLEAN)" do
    # pending "http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/92"
    
    ted = Exhibit.create(:name => 'Ted')
    ted.should_not be_dirty
    
    zest = Animal.create(:name => 'Zest')
    zest.should_not be_dirty
    
    ted.animals << zest
    ted.should be_dirty
    ted.save
    
    ted.reload!
    ted.should_not be_dirty
    ted.should have(1).animals
    
    ted2 = Exhibit[ted.key]
    ted2.should_not be_dirty
    ted2.should have(1).animals
    
    ted2.destroy!
    zest.destroy!
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
    
    delete_me = walter.animals.first
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
    pending("some borkage here")
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

  it "should raise an error when attempting to associate an object not of the correct type (assuming added model doesn't inherit from the correct type)" do
    # pending("see: http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/91")
    @amazonia.animals.should_not be_empty
    chuck = Person.new(:name => "Chuck")
    
    ## InvalidRecord isn't the error we should use here....needs to be changed
    lambda { @amazonia.animals << chuck }.should raise_error(ArgumentError)
    
  end

  it "should associate an object which has inherited from the correct type into an association" do
    # pending("see: http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/91")
    programmer = Career.first(:name => 'Programmer')
    programmer.followers.should_not be_empty
    
    sales_person = SalesPerson.new(:name => 'Chuck')
    
    lambda { programmer.followers << sales_person }.should_not raise_error(ArgumentError)
    
  end

end