describe DataMapper::Adapters::Sql::Coersion do
  
  before(:all) do
    @coersive = Class.new do
      include DataMapper::Adapters::Sql::Coersion
    end.new
  end
  
  it 'should cast to a BigDecimal' do
    target = BigDecimal.new('7.2')
    @coersive.type_cast_decimal('7.2').should == target
    @coersive.type_cast_decimal(7.2).should == target
  end
  
end