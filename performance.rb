require 'active_record'

ActiveRecord::Base.establish_connection :adapter => 'mysql',
  :host     => 'localhost',
  :username => 'root',
  :password => '',
  :database => 'data_mapper_1'
      
class ARAnimal < ActiveRecord::Base
  set_table_name 'animals'
end

class ARPerson < ActiveRecord::Base
  set_table_name 'people'
end

require 'lib/data_mapper'

log_path = File.dirname(__FILE__) + '/development.log'

require 'fileutils'
FileUtils::rm log_path if File.exists?(log_path)

DataMapper::Database.setup({
  :adapter => 'mysql',
  :database => 'data_mapper_1',
  :username => 'root'
})

class DMAnimal < DataMapper::Base
  set_table_name 'animals'
  property :name, :string
  property :notes, :string, :lazy => true
end

class DMPerson < DataMapper::Base
  set_table_name 'people'
  property :name, :string
  property :age, :integer
  property :occupation, :string
  property :notes, :text, :lazy => true
  property :street, :string
  property :city, :string
  property :state, :string, :size => 2
  property :zip_code, :string, :size => 10
end

class Exhibit < DataMapper::Base
  property :name, :string
  belongs_to :zoo
end

class Zoo < DataMapper::Base
  property :name, :string
  has_many :exhibits
end

class ARZoo < ActiveRecord::Base
  set_table_name 'zoos'
  has_many :exhibits, :class_name => 'ARExhibit', :foreign_key => 'zoo_id'
end

class ARExhibit < ActiveRecord::Base
  set_table_name 'exhibits'
  belongs_to :zoo, :class_name => 'ARZoo', :foreign_key => 'zoo_id'
end

N = (ENV['N'] || 1000).to_i

# 4.times do
#   [DMAnimal, Zoo, Exhibit].each do |klass|
#     klass.all.each do |instance|
#       klass.create(instance.attributes.reject { |k,v| k == :id })
#     end
#   end
# end

Benchmark::send(ENV['BM'] || :bmbm, 40) do |x|
  
  x.report('ActiveRecord:id') do
    N.times { ARAnimal.find(1) }
  end
  
  x.report('DataMapper:id') do
    N.times { DMAnimal[1] }
  end
  
  x.report('DataMapper:id:in-session') do
    database do
      N.times { DMAnimal[1] }
    end
  end
  
  x.report('ActiveRecord:all') do
    N.times { ARAnimal.find(:all) }
  end
  
  x.report('DataMapper:all') do
    N.times { DMAnimal.all }
  end
  
  x.report('DataMapper:all:in-session') do
    database do
      N.times { DMAnimal.all }
    end
  end
  
  x.report('ActiveRecord:conditions') do
    N.times { ARZoo.find(:first, :conditions => ['name = ?', 'Galveston']) }
  end
  
  x.report('DataMapper:conditions:short') do
    N.times { Zoo[:name => 'Galveston'] }
  end
  
  x.report('DataMapper:conditions:short:in-session') do
    database do
      N.times { Zoo[:name => 'Galveston'] }
    end
  end
  
  x.report('DataMapper:conditions:long') do
    N.times { Zoo.find(:first, :conditions => ['name = ?', 'Galveston']) }
  end
  
  x.report('DataMapper:conditions:long:in-session') do
    database do
      N.times { Zoo.find(:first, :conditions => ['name = ?', 'Galveston']) }
    end
  end
  
  people = [
    ['Sam', 29, 'Programmer', 'A slow text field'],
    ['Amy', 28, 'Business Analyst Manager', 'A slow text field'],
    ['Scott', 25, 'Programmer', 'A slow text field'],
    ['Josh', 23, 'Supervisor', 'A slow text field'],
    ['Bob', 40, 'Peon', 'A slow text field']
    ]

  DMPerson.truncate!
  
  x.report('ActiveRecord:insert') do
    N.times do
      people.each do |a|
        ARPerson::create(:name => a[0], :age => a[1], :occupation => a[2], :notes => a[3])
      end
    end
  end
  
  DMPerson.truncate!
  
  x.report('DataMapper:insert') do
    N.times do
      people.each do |a|
        DMPerson::create(:name => a[0], :age => a[1], :occupation => a[2], :notes => a[3])
      end
    end
  end
  
  x.report('ActiveRecord:update') do
    N.times do
      bob = ARAnimal.find(:first, :conditions => ["name = ?", 'Elephant'])
      bob.notes = 'Updated by ActiveRecord'
      bob.save
    end
  end
  
  x.report('DataMapper:update') do
    N.times do
      bob = DMAnimal.first(:name => 'Elephant')
      bob.notes = 'Updated by DataMapper'
      bob.save
    end
  end
  
  x.report('ActiveRecord:associations:lazy') do
    N.times do
      zoos = ARZoo.find(:all)
      zoos.each { |zoo| zoo.exhibits.entries }
    end
  end
  
  x.report('ActiveRecord:associations:included') do
    N.times do
      zoos = ARZoo.find(:all, :include => [:exhibits])
      zoos.each { |zoo| zoo.exhibits.entries }
    end
  end
  
  x.report('DataMapper:associations') do
    N.times do
      Zoo.all.each { |zoo| zoo.exhibits.entries }
    end
  end
  
  x.report('DataMapper:associations:in-session') do
    database do
      N.times do
        Zoo.all.each { |zoo| zoo.exhibits.entries }
      end
    end
  end
  
  x.report('ActiveRecord:find_by_sql') do
    N.times do
      ARZoo.find_by_sql("SELECT * FROM zoos")
    end
  end
  
  x.report('DataMapper:find_by_sql') do
    N.times do
      database.query("SELECT * FROM zoos")
    end
  end
  
  x.report('ActiveRecord:accessors') do
    person = ARPerson.find(:first)
      
    N.times do
      <<-VCARD
        #{person.name} (#{person.age})
        #{person.occupation}
        
        #{person.street}
        #{person.city}, #{person.state} #{person.zip_code}
        
        #{person.notes}
      VCARD
    end
  end
  
  x.report('DataMapper:accessors') do
    person = DMPerson.first
      
    N.times do
      <<-VCARD
        #{person.name} (#{person.age})
        #{person.occupation}
        
        #{person.street}
        #{person.city}, #{person.state} #{person.zip_code}
        
        #{person.notes}
      VCARD
    end
  end
    
    
end