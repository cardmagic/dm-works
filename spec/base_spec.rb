describe DataMapper::Base do
  
  it('attributes method should load all lazy-loaded values') do
    Animal.first(:name => 'Cup').attributes[:notes].should == 'I am a Cup!'
  end
  
end