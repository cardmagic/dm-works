describe DataMapper::Support::Serialization do
  
  before(:all) do
    fixtures(:animals)
  end
  
  it "should serialize to YAML" do
    Animal.first(:name => 'Frog').to_yaml.should == <<-EOS.margin
      --- 
      id: 1
      name: Frog
      notes: I am a Frog!
      
    EOS
  end
  
  it "should serialize to XML" do
    Animal.first(:name => 'Frog').to_xml.should == <<-EOS.compress_lines(false)
      <animal id="1">
        <name>Frog</name>
        <notes>I am a Frog!</notes>
      </animal>
    EOS
    
    san_diego_zoo = Zoo.first(:name => 'San Diego')
    san_diego_zoo.to_xml.should == <<-EOS.compress_lines(false)
      <zoo id="2">
        <name>San Diego</name>
        <notes/>
        <updated_at>#{san_diego_zoo.updated_at}</updated_at>
      </zoo>
    EOS
  end
  
end