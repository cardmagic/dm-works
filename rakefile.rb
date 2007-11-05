#!/usr/bin/env ruby

require 'rake'
require 'spec/rake/spectask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'

Dir[File.dirname(__FILE__) + '/tasks/*'].each { |t| require(t) }

task :default => 'dm:spec'

task :environment => 'dm:environment'

namespace :dm do

  desc "Setup Environment"
  task :environment do
    require 'environment'
  end
  
  desc "Run specifications"
  Spec::Rake::SpecTask.new('spec') do |t|
    t.spec_opts = ["--format", "specdoc", "--colour"]
    t.spec_files = FileList[(ENV['FILES'] || 'spec/**/*_spec.rb')]
  end
  
  desc "Run comparison with ActiveRecord"
  task :perf do
    load 'performance.rb'
  end

  desc "Profile DataMapper"
  task :profile do
    load 'profile_data_mapper.rb'
  end

end

PACKAGE_VERSION = '0.2.3'

PACKAGE_FILES = FileList[
  'README',
  'CHANGELOG',
  'MIT-LICENSE',
  '*.rb',
  'lib/**/*.rb',
  'spec/**/*.{rb,yaml}',
  'tasks/**/*',
  'plugins/**/*'
].to_a.reject { |path| path =~ /(\/db|Makefile|\.bundle|\.log|\.o)$/ }

DOCUMENTED_FILES = PACKAGE_FILES.reject do |path|
  FileTest.directory?(path) || path =~ /(^spec|\/spec|\/swig\_)/
end

PROJECT = 'datamapper'

task :ls do
  p PACKAGE_FILES
end

desc "Generate Documentation"
rd = Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title = "DataMapper -- An Object/Relational Mapper for Ruby"
  rdoc.options << '--line-numbers' << '--inline-source' << '--main' << 'README'
  rdoc.rdoc_files.include(*DOCUMENTED_FILES)
end

gem_spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY 
  s.name = PROJECT 
  s.summary = "An Object/Relational Mapper for Ruby"
  s.description = "Faster, Better, Simpler."
  s.version = PACKAGE_VERSION 
 
  s.authors = 'Sam Smoot'
  s.email = 'ssmoot@gmail.com'
  s.rubyforge_project = PROJECT 
  s.homepage = 'http://datamapper.org' 
 
  s.files = PACKAGE_FILES 
 
  s.require_path = 'lib'
  s.requirements << 'none'
  s.autorequire = 'data_mapper'
  s.add_dependency('fastthread')
  s.add_dependency('rspec')

  s.has_rdoc = true 
  s.rdoc_options << '--line-numbers' << '--inline-source' << '--main' << 'README'
  s.extra_rdoc_files = DOCUMENTED_FILES
end

Rake::GemPackageTask.new(gem_spec) do |p|
  p.gem_spec = gem_spec
  p.need_tar = true
  p.need_zip = true
end

desc "Publish to RubyForge"
task :rubyforge => [ :rdoc, :gem ] do
  Rake::SshDirPublisher.new("#{ENV['RUBYFORGE_USER']}@rubyforge.org", "/var/www/gforge-projects/#{PROJECT}", 'doc').upload
end

task :install => :package do
  sh %{sudo gem install pkg/#{PROJECT}-#{PACKAGE_VERSION}}
end