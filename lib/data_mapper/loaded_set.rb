require 'data_mapper/support/enumerable'

module DataMapper

  # LoadedSet's purpose is to give a common reference for the results of a query,
  # so that they can be manipulated by the DataMapper, behind-the-scenes, as a set.
  class LoadedSet
    
    # Provides a reference to the database that originally loaded the instances.
    attr_reader :database
    # Provides an Enumerable of the instances loaded in the set.
    attr_reader :instances
    
    def initialize(database)
      @database = database
      @instances = [] # ObjectIdCollection.new
    end
    
    # Not sure if this is necessary yet...
    # In other words: Does it make sense to allow portions of a set to be
    # garbage-collected?
    #
    # If so, then this isn't good enough because it's likely to
    # throw errors. If it's not, then letting Ruby itself track the
    # references with a simple Array is probably more effecient.
    class ObjectIdCollection
      
      include Enumerable
      include Support::Enumerable
      
      def initialize
        @object_ids = []
      end
      
      def each
        @object_ids.map { |id| yield ObjectSpace::_id2ref(id) }
      end
      
      def <<(object)
        @object_ids << object.object_id
      end
    end
  end

end