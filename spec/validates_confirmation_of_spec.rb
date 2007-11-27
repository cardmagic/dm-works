require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Validations::ConfirmationValidator do
  
  before(:all) do
    class Cow

      include DataMapper::CallbacksHelper
      include DataMapper::Validations::ValidationHelper
      
      attr_accessor :name, :name_confirmation, :age
    end
  end
  
  it 'should pass validation' do
    class Cow
      validations.clear!
      validates_confirmation_of :name, :context => :save
    end
    
    betsy = Cow.new
    betsy.valid?.should == true

    betsy.name = 'Betsy'
    betsy.name_confirmation = ''
    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == 'Name does not match the confirmation'

    betsy.name = ''
    betsy.name_confirmation = 'Betsy'
    betsy.valid?(:save).should == false
    betsy.errors.full_messages.first.should == 'Name does not match the confirmation'

    betsy.name = 'Betsy'
    betsy.name_confirmation = 'Betsy'
    betsy.valid?(:save).should == true
  end
  
  it 'should allow allow a custom error message' do
    class Cow
      validations.clear!
      validates_confirmation_of :name, :context => :save, :message => 'You confirm name NOW or else.'
    end
    
    betsy = Cow.new
    betsy.valid?.should == true

    betsy.name = 'Betsy'
    betsy.name_confirmation = ''
    betsy.valid?(:save).should == false

    betsy.errors.full_messages.first.should == 'You confirm name NOW or else.'
  end
  
end

describe DataMapper::Validations::ConfirmationValidator, "implements optional clauses" do
    before(:all) do
      class Sheep

        include DataMapper::CallbacksHelper
        include DataMapper::Validations::ValidationHelper

        attr_accessor :name, :age

        def evaluate?(value = true);value;end
      end
    end
    
    it "should implement the :if clause" do
      class Sheep
        validations.clear!
        validates_confirmation_of :name, :if => :evaluate?
      end
      sheep = Sheep.new
      sheep.should_receive(:evaluate?).once
      sheep.valid?        
    end
end