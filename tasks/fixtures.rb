namespace :dm do
  namespace :fixtures do
    require 'yaml'
    
    def fixtures_path
      return ENV['FIXTURE_PATH'] if ENV['FIXTURE_PATH']
      
      %w(db dev schema spec).find do |parent|
        test_for_dir = "#{DM_APP_ROOT}/#{parent}/fixtures"
        File.exists?(test_for_dir) ? test_for_dir : nil
      end
    end
    
    desc 'Dump database fixtures'
    task :dump do
      directory fixtures_path
      puts DataMapper::Base.subclasses.join("\n")
      DataMapper::Base.subclasses.each do |table|
        puts "Dumping #{table}"
        File.open( "#{fixtures_path}/#{table.to_s.underscore}.yml", "w") do |f|
          f.write YAML::dump(table.all.map{|r| r.attributes})
        end
      end
    end
    
    desc 'Load database fixtures'
    task :load do
      directory fixtures_path
      DataMapper::Base.subclasses.each do |table|
        file_name = "#{fixtures_path}/#{table.to_s.underscore}.yml"
        next unless File.exists?( file_name )
        puts "Loading #{table}"
        table.delete_all
        File.open( file_name, "r") do |f|
          YAML::load(f).each do |attrs|
            table.create attrs
          end
        end
      end
    end
  end
end