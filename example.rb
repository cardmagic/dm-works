require 'data_mapper'

if ENV['ADAPTER'] == 'sqlite3'
  DataMapper::Database.setup do
    adapter  'sqlite3'
    database 'data_mapper_1.db'
    log_stream 'example.log'
    log_level Logger::DEBUG
  end
else
  DataMapper::Database.setup do
    adapter  'mysql'
    host     'localhost'
    username 'root'
    database 'data_mapper_1'
    log_stream 'example.log'
    log_level Logger::DEBUG
  end
end

Dir[File.dirname(__FILE__) + '/spec/models/*.rb'].each do |path|
  load path
end