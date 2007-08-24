module DataMapper
  module Adapters
    module Sql
      module Commands
        
        class Loader
          
          def initialize(load_command, klass)
            @load_command, @klass = load_command, klass
            @columns = {}
            @key = nil
            @key_index = nil
            @session = load_command.session
            @reload = load_command.reload?
            @set = []
          end
          
          def add_column(column, index)
            if column.key?
              @key = column 
              @key_index = index
            else
              @columns[index] = column
            end
          
            self
          end
          
          def materialize(values)

            instance_id = @key.type_cast_value(values[@key_index])
            instance = create_instance(instance_id)
            
            @klass.callbacks.execute(:before_materialize, instance)
            
            original_hashes = {}
            
            @columns.each_pair do |index, column|
              # This may be a little confusing, but we're
              # setting both the original-hash value, and the
              # instance-variable through method chaining to avoid
              # lots of extra short-lived local variables.
              hashes[column.name] = instance.instance_variable_set(
                column.instance_variable_name,
                column.type_cast_value(values[index])
              ).hash
            end
            
            instance.instance_variable_set(:@original_hashes, original_hashes)
            
            instance.instance_variable_set(:@loaded_set, @set)
            @set << instance
            
            @klass.callbacks.execute(:after_materialize, instance)
            
            return instance
          end
          
          def loaded_set
            @set
          end
          
          private
          
            def create_instance(instance_id)
              instance = @session.identity_map.get(@klass, instance_id)

              if instance.nil? || @reload
                instance = instance_class.new()
                instance.instance_variable_set(:@__key, instance_id)
                instance.instance_variable_set(:@new_record, false)
                @session.identity_map.set(instance)
              end

              instance.session = @session

              return instance
            end
          
        end
        
      end # module Commands
    end # module Sql
  end # module Adapters
end # module DataMapper