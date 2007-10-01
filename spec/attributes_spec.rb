describe DataMapper::Base do
    
  it 'should allow mass-assignment of attributes' do
    zoo = Zoo.new(:name => 'MassAssignment', :notes => 'This is a test.')
    
    zoo.name.should eql('MassAssignment')
    zoo.notes.should eql('This is a test.')
    
    zoo.attributes = { :name => 'ThroughAttributesEqual', :notes => 'This is another test.' }
    
    zoo.name.should eql('ThroughAttributesEqual')
    zoo.notes.should eql('This is another test.')
  end
  
end