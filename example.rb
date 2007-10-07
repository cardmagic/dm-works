#!/usr/bin/env ruby

require 'irb'
require 'lib/data_mapper'

adapter = ENV['ADAPTER'] || 'sqlite3'
configuration_options = {
  :adapter => adapter,
  :log_stream => 'example.log',
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

DataMapper::Database.setup(configuration_options)

Dir[File.dirname(__FILE__) + '/spec/models/*.rb'].each do |path|
  load path
end

IRB::start

if false

# Simple example to setup a database:
DataMapper::Database.setup({
  :adapter => 'mysql',
  :database => 'data_mapper_1',
  :username => 'root'
})

class Animal < DataMapper::Base
  set_table_name 'animals' # Just as an example. Same inflector as Rails,
    # so this really isn't necessary.
    
  property :name, :string
  property :notes, :string, :lazy => true
  
  has_and_belongs_to_many :exhibits
end

class Exhibit < DataMapper::Base
  property :name, :string
  belongs_to :zoo
end

class Zoo < DataMapper::Base
  property :name, :string
  has_many :exhibits
end

class Person < DataMapper::Base

  property :name, :string
  property :age, :integer
  property :occupation, :string
  property :notes, :text, :lazy => true

  # Generates Person::Address class:
  embed :address do
    property :street, :string
    property :city, :string
    property :state, :string, :size => 2
    property :postal_code, :string
  end
end

# Compatible with ActiveRecord finder syntax:
Zoo.find(1)
Zoo.find(:first, :conditions => ['name = ?', 'Galveston'])
Zoo.find(:all)

# These are options as well:
Zoo[1]
Zoo.first(:name => 'Galveston')
Zoo.all

# Or even this as an alias to ::first:
Zoo[:name => 'Galveston']

# EmbeddedValues are just nice sugar to partition
# denormalized data.
Person.first.address.city

# Remove all data in a table...  
Person.truncate!
  
# Create a new object...
Person::create(:name => 'Sam', :age => 30, :occupation => 'Software Monkey')

# Saving only updates the values that have changed,
# and is skipped entirely if the object is not dirty.
dumbo = Animal.first(:name => 'Elephant')
dumbo.notes = 'He can fly!'
dumbo.save # returns true
dumbo.save # The object is no longer dirty, so returns false
  
# DataMapper associations are loaded as sets.
# Here's the code:
Zoo.all.each { |zoo| zoo.exhibits.entries }
# The important bit to understand about the above is that
# every Zoo that was loaded by Zoo.all has a reference to
# every other Zoo it was loaded with through Zoo#loaded_set.
# This is then used to load all other instances in the set
# when the association of one instance is accessed. So while
# it looks like we'd run into the dreaded 1+N query problem
# with the above, we actually avoid it entirely. The above
# code will only execute two queries. The first to find all
# zoos, the second to load all exhibits with zoo_id's that
# are a part of the set of loaded zoos.


# Objects within the same session are uniqued, so this is both
# faster, and fulfills obvious expectations.
database do
  Zoo.first == Zoo.first
end

# DataMapper find_by_sql equivilent
database.query("SELECT * FROM zoos")

end