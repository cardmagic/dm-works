describe "Conversion to YAML" do
  # check each model to see if the conversion *.to_yaml works.
  Dir[File.dirname(__FILE__) + "/fixtures/*.yaml"].each do |path|
    name = File::basename(path).sub(/\.yaml$/, '')
    klass = Kernel::const_get(Inflector.classify(Inflector.singularize(name)))
    it "the first #{klass} converted to YAML should match the YAML in the fixture" do
      klass.first.to_yaml.should == YAML::load_file("./spec/fixtures/#{name}.yaml")[0].to_yaml
    end
  end
end