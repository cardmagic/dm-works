module DataMapper
  module Adapters
      
    class AbstractAdapter
  
      # Instantiate an Adapter by passing it a DataMapper::Database
      # object for configuration.
      def initialize(configuration)
        @configuration = configuration
      end
      
      def index_path
        @configuration.index_path
      end
      
      def name
        @configuration.name
      end
      
      def delete(instance_or_klass, options = nil)
        raise NotImplementedError.new
      end
      
      def save(database_context, instance)
        raise NotImplementedError.new
      end
      
      def load(database_context, klass, options)
        raise NotImplementedError.new
      end
      
      def get(database_context, klass, *keys)
        raise NotImplementedError.new
      end
      
      def logger
        @logger || @logger = @configuration.logger
      end
      
      protected
      
      def materialize(database_context, klass, values, reload, loaded_set)
        
        table = self.table(klass)
        
        instance_id = table.key.type_cast_value(values[table.key.name])
        
        instance_type = if table.multi_class? && table.type_column
          values.has_key?(table.type_column.name) ?
            table.type_column.type_cast_value(values[table.type_column.name]) : klass
        else
          klass
        end
        
        instance = create_instance(database_context, instance_type, instance_id, reload)
        
        instance_type.callbacks.execute(:before_materialize, instance)
        
        type_casted_values = {}
        
        values.each_pair do |k,v|
          column = table[k]
          type_cast_value = column.type_cast_value(v)
          type_casted_values[k] = type_cast_value
          instance.instance_variable_set(column.instance_variable_name, type_cast_value)
        end
        
        instance.original_values = type_casted_values
        instance.loaded_set = loaded_set

        instance_type.callbacks.execute(:after_materialize, instance)

        return instance
        
      #rescue => e
      #  raise MaterializationError.new("Failed to materialize row: #{values.inspect}\n#{e.to_yaml}")
      end
      
      def create_instance(database_context, instance_type, instance_id, reload)
        instance = database_context.identity_map.get(instance_type, instance_id)

        if instance.nil? || reload
          instance = instance_type.new() if instance.nil?
          instance.instance_variable_set(:@__key, instance_id)
          instance.instance_variable_set(:@new_record, false)
          database_context.identity_map.set(instance)
        elsif instance.new_record?
          instance.instance_variable_set(:@__key, instance_id)
          instance.instance_variable_set(:@new_record, false)
        end

        instance.database_context = database_context

        return instance
      end
      
    end # class AbstractAdapter
    
  end # module Adapters
end # module DataMapper