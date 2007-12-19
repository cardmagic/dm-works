module DataMapper
  module Support
    
    module ActiveRecordImpersonation
      
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      def save
        database_context.save(self)
      end
      
      def reload!
        database_context.first(self.class, key, :select => original_values.keys, :reload => true)
        self.loaded_associations.each { |association| association.reload! }
        self
      end
      
      def reload
        reload!
      end
      
      def destroy!
        database_context.destroy(self)
      end
      
      module ClassMethods
        
        def find_or_create(search_attributes, create_attributes = {})
          first(search_attributes) || create(search_attributes.merge(create_attributes))
        end
        
        def all(options = {})
          database.all(self, options)
        end
        
        def each(options = {}, &b)
          raise ArgumentError.new(":offset is not supported with the #each method") if options.has_key?(:offset)

          offset = 0
          limit = options[:limit] || (self::const_defined?('DEFAULT_LIMIT') ? self::DEFAULT_LIMIT : 500)

          until (results = all(options.merge(:limit => limit, :offset => offset))).empty?
            results.each(&b)
            offset += limit
          end
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
        
        def create!(attributes)
          instance = self.new(attributes)
          instance.save
          raise InvalidRecord.new(instance) if instance.new_record?
          instance
        end
      end
    end
    
  end
end
