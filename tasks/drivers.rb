namespace :dm do
  namespace :install do
    
    desc 'Install DataObjects.rb Mysql Driver'
    task :mysql do
      %x(cd #{File.dirname(__FILE__) + '/../plugins/dataobjects/swig_mysql/'} && ruby extconf.rb && make && sudo make install)
    end
    
    desc 'Install DataObjects.rb SQLite3 Driver'
    task :sqlite3 do
      %x(cd #{File.dirname(__FILE__) + '/../plugins/dataobjects/swig_sqlite/'} && ruby extconf.rb && make && sudo make install)
    end
    
    desc 'Install DataObjects.rb PostgreSQL Driver'
    task :postgresql do
      %x(cd #{File.dirname(__FILE__) + '/../plugins/dataobjects/swig_postgres/'} && ruby extconf.rb && make && sudo make install)
    end
    
  end
end