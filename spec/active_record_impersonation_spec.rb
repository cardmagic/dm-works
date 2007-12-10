require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Support::ActiveRecordImpersonation do
  
  before(:all) do
    fixtures(:animals)
    fixtures(:exhibits)
  end
  
  describe 'A record' do
    it 'should save and return true if validations pass' do
      count = Exhibit.count
      bugs_and_more_bugs = Exhibit.new(:name => 'Bugs And More Bugs')
      bugs_and_more_bugs.save.should be_true
      Exhibit.count.should == count + 1
    end

    it 'should return false on save if validations fail' do
      count = Exhibit.count
      bugs_and_more_bugs = Exhibit.new
      bugs_and_more_bugs.save.should be_false
      Exhibit.count.should == count
    end

    it 'should reload its attributes' do
      frog = Animal[:name => 'Frog']
      frog.name = 'MegaFrog'
      frog.name.should == 'MegaFrog'
      frog.reload!
      frog.name.should == 'Frog'
    end
    
    it "should prepare it's associations for reload" do
      chippy = Animal.first(:name => 'Cup')
      amazonia = Exhibit.first(:name => 'Amazonia')
      amazonia.animals << chippy
      amazonia.animals.should include(chippy)
      amazonia.reload!
      amazonia.animals.should_not include(chippy)
    end

    it 'should be destroyed!' do
      capybara = Animal.create(:name => 'Capybara')
      count = Animal.count
      capybara.destroy!
      Animal[:name => 'Capybara'].should be_nil
      Animal.count.should == count - 1
    end
  end

  it 'should return the first match using find_or_create' do
    count = Animal.count
    frog = Animal.find_or_create(:name => 'Frog')
    frog.name.should == 'Frog'
    Animal.count.should == count
  end

  it 'should create a record if a match is not found with find_or_create' do
    count = Animal.count
    capybara = Animal.find_or_create(:name => 'Capybara')
    capybara.name.should == 'Capybara'
    Animal.count.should == count + 1
  end

  it 'should return all records' do
    all_animals = Animal.all
    all_animals.length.should == Animal.count
    all_animals.each do |animal|
      animal.class.should == Animal
    end
  end

  it 'should return the first record' do
    Animal.first.should == Animal.find(:first)
  end

  it 'should return a count of the records' do
    Animal.count.should == Animal.find_by_sql("SELECT COUNT(*) FROM animals")[0]
  end

  it 'should delete all records' do
    Animal.delete_all
    Animal.count.should == 0

    fixtures(:animals)
  end

  #it 'should be truncated' do
  #  Animal.truncate!
  #  Animal.count.should == 0
  #
  #  fixtures(:animals)
  #end

  it 'should find a matching record given an id' do
    Animal.find(1).name.should == 'Frog'
  end

  it 'should find all records' do
    Animal.find(:all).length.should == Animal.count
  end

  it 'should find all matching records given some condition' do
    Animal.find(:all, :conditions => ["name = ?", "Frog"])[0].name.should == 'Frog'
  end

  it 'should find the first matching record' do
    Animal.find(:first).name.should == 'Frog'
  end

  it 'should find the first matching record given some condition' do
    Animal.find(:first, :conditions => ["name = ?", "Frog"]).name.should == 'Frog'
  end

  it 'should select records using the supplied sql fragment' do
    Animal.find_by_sql("SELECT name FROM animals WHERE name='Frog'")[0].should == 'Frog'
  end

  it 'should retrieve the indexed element' do
    Animal[1].id.should == 1
  end

  it 'should retrieve the indexed element using a hash condition' do
    Animal[:name => 'Frog'].name.should == 'Frog'
  end

  it 'should create a new record' do
    count = Animal.count
    capybara = Animal.create(:name => 'Capybara')
    capybara.name.should == 'Capybara'
    Animal.count.should == count + 1
  end
end
