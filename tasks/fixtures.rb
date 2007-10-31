namespace :dm do
  namespace :fixtures do
    require 'yaml'
    
    def fixtures_path
      return ENV['FIXTURE_PATH'] if ENV['FIXTURE_PATH']
      
      fixture_path = %w(db dev schema spec).find do |parent|
        File.exists?("#{DM_APP_ROOT}/#{parent}/fixtures")
      end
      
      raise "Fixtures path not found." unless fixture_path
      
      "#{DM_APP_ROOT}/#{fixture_path}/fixtures"
    end
    
    desc 'Dump database fixtures'
    task :dump do
      ENV['AUTO_MIGRATE'] = 'false'
      Rake::Task['environment'].invoke
      directory fixtures_path
      DataMapper::Base.subclasses.each do |table|
        puts "Dumping #{table}"
        File.open( "#{fixtures_path}/#{Inflector.underscore(table.to_s)}.yml", "w+") do |file|
          file.write YAML::dump(table.all)
        end
      end
    end
    
    desc 'Load database fixtures'
    task :load do
      Rake::Task['environment'].invoke
      directory fixtures_path
      DataMapper::Base.subclasses.each do |table|
        file_name = "#{fixtures_path}/#{Inflector.underscore(table.to_s)}.yml"
        next unless File.exists?( file_name )
        puts "Loading #{table}"
        table.delete_all
        File.open( file_name, "r") do |file|
          YAML::load(file).each do |attributes|
            table.create(attributes)
          end
        end
      end
    end
  end
end