require File.dirname(__FILE__) + "/spec_helper"

describe 'Legacy mappings' do
  
  it('should allow models to map with custom attribute names') do
    Fruit.first.name.should == 'Kiwi'
  end
  
  it('should allow custom foreign-key mappings') do
    database do
      Fruit[:name => 'Watermelon'].devourer_of_souls.should == Animal[:name => 'Cup']
      Animal[:name => 'Cup'].favourite_fruit.should == Fruit[:name => 'Watermelon']
    end
  end
  
end