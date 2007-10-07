describe DataMapper::Base do
  
  it('attributes method should load all lazy-loaded values') do
    Animal.first(:name => 'Cup').attributes[:notes].should == 'I am a Cup!'
  end
  
end

describe 'A new record' do
  
  before(:each) do
    @bob = Person.new(:name => 'Bob', :age => 30, :occupation => 'Sales')
  end
  
  it 'should be dirty' do
    @bob.dirty?.should == true
  end
  
  it 'set attributes should be dirty' do
    attributes = @bob.attributes.dup.reject { |k,v| k == :id }
    @bob.dirty_attributes.should == { :name => 'Bob', :age => 30, :occupation => 'Sales' }
  end
  
  it 'should be marked as new' do
    @bob.new_record?.should == true
  end
  
  it 'should have a nil id' do
    @bob.id.should == nil
  end
  
end