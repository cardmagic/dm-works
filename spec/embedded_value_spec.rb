describe DataMapper::EmbeddedValue do
    
  it 'should proxy getting values for you' do
    bob = Person[:name => 'Bob']
    bob.address.street.should == '123 Happy Ln.'
  end
  
end