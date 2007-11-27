require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Validations do
  
  before(:all) do
    class Cow
      
      include DataMapper::CallbacksHelper
      include DataMapper::Validations::ValidationHelper
      
      attr_accessor :name, :age
    end
  end
  
  it 'should allow you to specify not-null fields in different contexts' do
    class Cow
      validations.clear!
      validates_presence_of :name, :context => :save
    end
    
    betsy = Cow.new
    betsy.valid?.should == true

    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == 'Name must not be blank'
    
    betsy.name = 'Betsy'
    betsy.valid?(:save).should == true
  end
  
  it 'should be able to use ":on" for a context alias' do
    class Cow
      validations.clear!
      validates_presence_of :name, :age, :on => :create
    end
    
    maggie = Cow.new
    maggie.valid?.should == true
    
    maggie.valid?(:create).should == false
    maggie.errors.full_messages.should include('Age must not be blank')
    maggie.errors.full_messages.should include('Name must not be blank')
    
    maggie.name = 'Maggie'
    maggie.age = 29
    maggie.valid?(:create).should == true
  end
  
  it 'should default to a general context if unspecified' do
    class Cow
      validations.clear!
      validates_presence_of :name, :age
    end
    
    rhonda = Cow.new
    rhonda.valid?.should == false
    rhonda.errors.should have(2).full_messages
    
    rhonda.errors.full_messages.should include('Age must not be blank')
    rhonda.errors.full_messages.should include('Name must not be blank')
    
    rhonda.name = 'Rhonda'
    rhonda.age = 44
    rhonda.valid?.should == true
  end
  
  it 'should have 1 validation error' do    
    class VPOTest
      
      include DataMapper::CallbacksHelper
      include DataMapper::Validations::ValidationHelper
      
      attr_accessor :name, :whatever
      
      validates_presence_of :name
    end

    o = VPOTest.new
    o.should_not be_valid
    o.errors.should have(1).full_messages
  end
  
  it 'should translate error messages' do
    String::translations["%s must not be blank"] = "%s should not be blank!"
  
    beth = Cow.new
    beth.age = 30
  
    beth.should_not be_valid
  
    beth.errors.full_messages.should include('Name should not be blank!')
  
    String::translations.delete("%s must not be blank")
  end

  it 'should be able to find specific error message' do
    class Cow
      validations.clear!
      validates_presence_of :name
    end

    gertie = Cow.new
    gertie.should_not be_valid
    gertie.errors.on(:name).should == ['Name must not be blank']
    gertie.errors.on(:age).should == nil
  end
  
  it "should be able to specify custom error messages" do
    class Cow
      validations.clear!
      validates_presence_of :name, :message => 'Give me a name, bub!'
    end
    
    gertie = Cow.new
    gertie.should_not be_valid
    gertie.errors.on(:name).should == ['Give me a name, bub!']    
  end
  
end

describe DataMapper::Validations, ":if clause" do
  
  before(:all) do
    class Sheep
      
      include DataMapper::CallbacksHelper
      include DataMapper::Validations::ValidationHelper
      
      attr_accessor :name, :age
    end
  end
  
  it "should execute a proc found in an :if clause" do
    class Sheep
      validations.clear!
      validates_presence_of :name, :if => Proc.new{ |model| model.evaluate?(false) } 
      
      def evaluate?(value = true);value;end
    end
    
    sheep = Sheep.new
    sheep.should_receive(:evaluate?).once
    sheep.valid?
  end
  
  it "should execute a method on the target provided as a symbol in an :if clause" do
    class Sheep
      validations.clear!
      validates_presence_of :name, :if => :evaluate?
      
      def evaluate?(value = true);value;end
    end
    
    sheep = Sheep.new
    sheep.should_receive(:evaluate?).once
    sheep.valid?
  end
  
  it "should not run validation if an :if clause is present as a proc and evaluates to false" do
    class Sheep
      validations.clear!
      validates_presence_of :name, :if => Proc.new{ |model| model.evaluate?(false)}
      
      def evaluate?(value = true);value;end
    end
    sheep = Sheep.new
    sheep.valid?
    sheep.errors.full_messages.should_not include('Name must not be blank')
  end
  
  it "should run validation if an :if clause is present as a proc and evaluates to true" do
    class Sheep
      validations.clear!
      validates_presence_of :name, :if => Proc.new{ |model| model.evaluate?(true)}
      
      def evaluate?(value = true);value;end
    end
    sheep = Sheep.new
    sheep.valid?
    sheep.errors.full_messages.should include('Name must not be blank')
  end
  
  it "should not run validation if an :if clause is present as a symbol of a method name and evaluates to false" do
    class Sheep
      validations.clear!
      validates_presence_of :name, :if => :evaluate? 
      
      def evaluate?;false;end
    end
    sheep = Sheep.new
    sheep.valid?
    sheep.errors.full_messages.should_not include('Name must not be blank')
  end
  
  it "should run validation if an :if clause is present as a symbol of a method name and evaluates to true" do
    class Sheep
      validations.clear!
      validates_presence_of :name, :if => :evaluate?
      
      def evaluate?;true;end
    end
    sheep = Sheep.new
    sheep.valid?
    sheep.errors.full_messages.should include('Name must not be blank')    
  end
  
  it "should run validation if no :if clause is present" do
    class Sheep
      validations.clear!
      validates_presence_of :name
    end
    sheep = Sheep.new
    sheep.valid?
    sheep.errors.full_messages.should include('Name must not be blank')
  end
    
end
