require File.dirname(__FILE__) + '/../lib/data_mapper'
require File.dirname(__FILE__) + '/mock_adapter'
require 'yaml'
require 'pp'

log_path = File.dirname(__FILE__) + '/../spec.log'

require 'fileutils'
FileUtils::rm log_path if File.exists?(log_path)

adapter = ENV['ADAPTER'] || 'sqlite3'
configuration_options = {
  :adapter => adapter,
  :log_stream => 'spec.log',
  :log_level => Logger::DEBUG,
  :database =>  ENV['DATABASE'] || (adapter == 'sqlite3' ? ':memory:' : 'data_mapper_1'),
  :single_threaded => false
}

case adapter
  when 'postgresql' then
    configuration_options[:username] = ENV['USERNAME'] || 'postgres'
  when 'mysql' then
    configuration_options[:username] = 'root'
  when 'sqlite3' then
    configuration_options[:database] << '.db' if configuration_options[:database] != ':memory:'
end

def load_models
  Dir[File.dirname(__FILE__) + '/models/*.rb'].sort.each do |path|
    load path
  end
end

DataMapper::Database.setup(:default, configuration_options)

database do |db|
  load_models
  DataMapper::Base::auto_migrate!
end

mock_db = DataMapper::Database.setup(:mock, {})
mock_db.adapter = MockAdapter.new(mock_db)
database(:mock) { load_models }

at_exit do
  database do |db|
    db.schema.each do |table|
      db.drop_table(table.klass)
    end
  end
end if ENV['DROP'] == '1'

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
