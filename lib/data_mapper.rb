# This line just let's us require anything in the +lib+ sub-folder
# without specifying a full path.
$LOAD_PATH.unshift(File.dirname(__FILE__))

# Require the basics...
require 'set'
require 'fastthread'
require 'data_mapper/support/blank'
require 'data_mapper/support/enumerable'
require 'data_mapper/support/symbol'
require 'data_mapper/support/string'
require 'data_mapper/support/inflector'
require 'data_mapper/support/struct'
require 'data_mapper/database'
require 'data_mapper/base'

# This block of code is for compatibility with Ruby On Rails' database.yml
# file, allowing you to simply require the data_mapper.rb in your
# Rails application's environment.rb to configure the DataMapper.
if defined?(RAILS_ROOT) && File.exists?(RAILS_ROOT + '/config/database.yml')
  require 'yaml'
  
  rails_config = YAML::load_file(RAILS_ROOT + '/config/database.yml')
  current_config = rails_config[RAILS_ENV.to_s]
  
  default_database_config = {
    :adapter  => current_config['adapter'],
    :host     => current_config['host'],
    :database => current_config['database'],
    :username => current_config['username'],
    :password => current_config['password']
  }
  
  if File.exists?(RAILS_ROOT + '/config/solr.yml')
    solr_config = YAML::load_file(RAILS_ROOT + '/config/solr.yml') 
    default_database_config.merge({ :solr => solr_config[RAILS_ENV]['url'] })
  end
  
  DataMapper::Database.setup(default_database_config)
end