module DataMapper
  module Support
    
    module ActiveRecordImpersonation
      
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      def save
        session.save(self)
      end
      
      def reload!
        session.first(self.class, key, :select => session.mappings[self.class].columns.map(&:name), :reload => true)
      end
      
      def reload
        reload!
      end
      
      def destroy!
        session.destroy(self)
      end
      
      module ClassMethods
        
        def find_or_create(search_attributes, create_attributes = nil)
          first(search_attributes) || create(search_attributes.merge(create_attributes))
        end
        
        def all(options = {})
          database.all(self, options)
        end
        
        def first(*args)
          database.first(self, *args)
        end
        
        def count(*args)
          database.count(self, *args)
        end
        
        def delete_all
          database.delete_all(self)
        end
        
        def truncate!
          database.truncate(self)
        end
        
        def find(type_or_id, options = {})
          case type_or_id
            when :first then first(options)
            when :all then all(options)
            else first(type_or_id, options)
          end
        end
        
        def find_by_sql(*args)
          DataMapper::database.query(*args)
        end
        
        def [](id_or_hash)
          first(id_or_hash)
        end
        
        def create(attributes)
          instance = self.new(attributes)
          instance.save
          instance
        end
      end
    end
    
  end
end