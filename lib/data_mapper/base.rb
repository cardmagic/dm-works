require 'data_mapper/persistence'

begin
  require 'ferret'
rescue LoadError
end

module DataMapper

  class Base
    include DataMapper::Persistence
    
    def self.inherited(klass)
      DataMapper::Persistence::prepare_for_persistence(klass)
    end

    def self.subclasses
      []
    end
  end
end
