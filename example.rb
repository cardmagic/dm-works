#!/usr/bin/env ruby

require 'lib/data_mapper'

adapter = ENV['ADAPTER'] || 'mysql'
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

# p Zoo.all