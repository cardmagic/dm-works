require 'data_mapper/persistence'

begin
  require 'ferret'
rescue LoadError
end

module DataMapper

  class Base
    
    def self.inherited(klass)
      klass.send(:include, DataMapper::Persistence)
    end

    def self.auto_migrate!
      DataMapper::Persistence.auto_migrate!
    end
  end
end
