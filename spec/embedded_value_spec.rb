describe DataMapper::EmbeddedValue do
    
  it 'should proxy getting values for you' do
    bob = Person[:name => 'Bob']
    bob.address.street.should == '123 Happy Ln.'
  end
  
  it 'should return a sub-class of the containing class' do
    bob = Person[:name => 'Bob']
    bob.address.class.should be(Person::Address)
  end
  
end