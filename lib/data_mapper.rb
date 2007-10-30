# This file begins the loading sequence.
#
# Quick Overview:
# * Requires set, fastthread, support libs, and base
# * Sets the applications root and environment for compatibility with rails or merb
# * Checks for the database.yml and loads it if it exists
# * Sets up the database using the config from the yaml file or from the environment
# * 

# This line just let's us require anything in the +lib+ sub-folder
# without specifying a full path.

$LOAD_PATH.unshift(File.dirname(__FILE__))

DM_PLUGINS_ROOT = (File.dirname(__FILE__) + '/../plugins')

# Require the basics...
require 'yaml'
require 'set'
require 'fastthread'
require 'data_mapper/support/blank'
require 'data_mapper/support/enumerable'
require 'data_mapper/support/symbol'
require 'data_mapper/support/string'
require 'data_mapper/support/inflector'
require 'data_mapper/database'
require 'data_mapper/base'

# This block of code is for compatibility with Ruby On Rails' or Merb's database.yml
# file, allowing you to simply require the data_mapper.rb in your
# Rails application's environment.rb to configure the DataMapper.

application_root, application_environment = *if defined?(MERB_ROOT)
  [MERB_ROOT, MERB_ENV]
elsif defined?(RAILS_ROOT)
  [RAILS_ROOT, RAILS_ENV]
end

unless defined?(DM_APP_ROOT)
  DM_APP_ROOT = application_root || Dir::pwd
end

if application_root && File.exists?(application_root + '/config/database.yml')
  
  database_configurations = YAML::load_file(application_root + '/config/database.yml')
  current_database_config = database_configurations[application_environment] || database_configurations[application_environment.to_sym]
  
  default_database_config = {
    :adapter  => current_database_config['adapter'] || current_database_config[:adapter],
    :host     => current_database_config['host'] || current_database_config[:host],
    :database => current_database_config['database'] || current_database_config[:database],
    :username => current_database_config['username'] || current_database_config[:username],
    :password => current_database_config['password'] || current_database_config[:password]
  }
  
  DataMapper::Database.setup(default_database_config)
end