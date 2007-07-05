describe DataMapper::Support::String do
  
  it 'should underscore camel-cased words' do
    String::memoized_underscore('DataMapper').should == 'data_mapper'
  end
  
end