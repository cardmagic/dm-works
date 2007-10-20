ENV['LOG_NAME'] = 'spec'
require File.dirname(__FILE__) + '/../environment'

# Define a fixtures helper method to load up our test data.
def fixtures(name, force = false)
  entry = YAML::load_file(File.dirname(__FILE__) + "/fixtures/#{name}.yaml")
  klass = Kernel::const_get(Inflector.classify(Inflector.singularize(name)))
  
  klass.auto_migrate!
  
  (entry.kind_of?(Array) ? entry : [entry]).each do |hash|
    if hash['type']
      Object::const_get(hash['type'])::create(hash)
    else
      klass::create(hash)
    end
  end
end

# Pre-fill the database so non-destructive tests don't need to reload fixtures.
Dir[File.dirname(__FILE__) + "/fixtures/*.yaml"].each do |path|
  fixtures(File::basename(path).sub(/\.yaml$/, ''), true)
end
