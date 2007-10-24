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
  
end