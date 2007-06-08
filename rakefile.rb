#!/usr/bin/env ruby

require 'rake'
require 'spec/rake/spectask'

task :default => 'test'

desc "Run specifications"
Spec::Rake::SpecTask.new('test') do |t|
  t.spec_opts = [ '-rspec/spec_helper' ]
  t.spec_files = FileList[ENV['FILES'] || 'spec/*.rb']
end

desc "Run comparison with ActiveRecord"
task :perf do
  load 'performance.rb'
end

desc "Profile DataMapper"
task :profile do
  load 'profile_data_mapper.rb'
end