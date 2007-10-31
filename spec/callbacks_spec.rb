require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Callbacks do
  
  it "should allow for a callback to be set, then called" do
    
    example = Class.new do
      include DataMapper::CallbacksHelper
      
      attr_accessor :name
      
      def initialize(name)
        @name = name
      end
      
      before_save 'name = "bob"'
      before_validation { |instance| instance.name = 'Barry White Returns!' }

    end.new('Barry White')
    
    example.class::callbacks.execute(:before_save, example)
    example.name.should == 'Barry White'
    
    example.class::callbacks.execute(:before_validation, example)
    example.name.should == 'Barry White Returns!'
  end
  
  it "should allow method delegation by passing symbols to the callback definitions" do
    
    example = Class.new do
      include DataMapper::CallbacksHelper
      
      attr_accessor :name
      
      before_save :test
      
      def test
        @name = 'Walter'
      end
    end.new
    
    example.class::callbacks.execute(:before_save, example)
    example.name.should == 'Walter'
    
  end
  
end