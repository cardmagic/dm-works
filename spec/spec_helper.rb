require File.dirname(__FILE__) + '/../lib/data_mapper'
require 'yaml'
require 'pp'

log_path = File.dirname(__FILE__) + '/../spec.log'

require 'fileutils'
FileUtils::rm log_path if File.exists?(log_path)

adapter = ENV['ADAPTER'] || 'mysql'
configuration_options = {
  :adapter => adapter,
  :log_stream => 'spec.log',
  :log_level => Logger::DEBUG,
  :database => 'data_mapper_1'
}

case adapter
  when 'postgresql' then
    configuration_options[:username] = 'postgres'
  when 'mysql' then
    configuration_options[:username] = 'root'
  when 'sqlite3' then
    configuration_options[:database] << '.db'
  else
    raise "Unsupported Adapter => #{adapter.inspect}"
end

def load_models
  Dir[File.dirname(__FILE__) + '/models/*.rb'].each do |path|
    load path
  end
end

DataMapper::Database.setup(:mock, :adapter => :mock)
database(:mock) { load_models }  

DataMapper::Database.setup(configuration_options)

database do |db|
  load_models
  db.schema.each do |table|
    db.create_table(table.klass)
  end
end

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
  
  database.schema[klass].drop! if force
  database.schema[klass].create!
  klass.truncate!
  
  (entry.kind_of?(Array) ? entry : [entry]).each do |hash|
    klass::create(hash)
  end
end

# Pre-fill the database so non-destructive tests don't need to reload fixtures.
Dir[File.dirname(__FILE__) + "/fixtures/*.yaml"].each do |path|
  fixtures(File::basename(path).sub(/\.yaml$/, ''), true)
end
