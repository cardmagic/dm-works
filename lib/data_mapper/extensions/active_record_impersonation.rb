module DataMapper
  module Extensions
    
    module ActiveRecordImpersonation
      
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      def save
        session.save(self)
      end
      
      def reload!
        session.find(self.class, id, :select => session.mappings[self.class].columns.map(&:name), :reload => true)
      end
      
      def reload
        reload!
      end
      
      def destroy!
        session.destroy(self)
      end
      
      module ClassMethods
        
        def all(options = {}, &b)
          find(:all, options, &b)
        end
        
        def first(options = {}, &b)
          find(:first, options, &b)
        end
        
        def delete_all
          database.delete_all(self)
        end
        
        def truncate!
          database.truncate(self)
        end
        
        def find(*args, &b)
          DataMapper::database.find(self, *args, &b)
        end
        
        def find_by_sql(*args)
          DataMapper::database.query(*args)
        end
        
        def [](id_or_hash)
          if id_or_hash.kind_of?(Hash)
            find(:first, id_or_hash)
          else
            find(id_or_hash)
          end
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