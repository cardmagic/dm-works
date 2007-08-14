require 'data_mapper/associations/has_many_association'
require 'data_mapper/associations/belongs_to_association'
require 'data_mapper/associations/has_one_association'
require 'data_mapper/associations/has_and_belongs_to_many_association'

module DataMapper
  module Associations
  
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      
      def has_many(association_name, options = {})
        database.schema[self].associations << HasManyAssociation.new(self, association_name, options)
      end
      
      def belongs_to(association_name, options = {})
        BelongsToAssociation.setup(self, association_name, options)
      end
      
      def has_and_belongs_to_many(association_name, options = {})
        HasAndBelongsToManyAssociation.setup(self, association_name, options)
      end
      
      def has_one(association_name, options = {})
        database.schema[self].associations << HasOneAssociation.new(self, association_name, options)
      end
      
    end
    
  end
end