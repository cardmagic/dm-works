require 'data_mapper/associations/has_n_association'

module DataMapper
  module Associations
    
    class HasManyAssociation < HasNAssociation
      
      # Define the association instance method (i.e. Project#tasks)
      def define_accessor(klass)
        klass.class_eval <<-EOS
          def #{@association_name}
            @#{@association_name} || (@#{@association_name} = DataMapper::Associations::HasManyAssociation::Set.new(self, #{@association_name.inspect}))
          end
        EOS
      end
      
      class Set < Associations::Reference
        
        include Enumerable
        
        def each
          entries.each { |item| yield item }
        end

        def size
          entries.size
        end
        alias length size

        def [](key)
          entries[key]
        end

        def empty?
          entries.empty?
        end
        
        def entries
          @entries || @entries = begin

            if @instance.loaded_set.nil?
              []
            else
              @instance.session.all(
                association.constant,
                association.foreign_key.to_sym => @instance.loaded_set.map(&:key)
              ).group_by(&association.foreign_key.to_sym).each do |key,instances|
                if instance = @instance.loaded_set.find { |entry| entry.key == key }
                  instance.send(@association_name).set(instances)
                end
              end
              
              @entries              
            end
          end
        end

        def set(results)
          @entries = results
        end

        def inspect
          @entries.inspect
        end
      end

    end
    
  end
end