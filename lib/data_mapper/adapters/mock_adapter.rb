require 'data_mapper/adapters/sql_adapter'

module DataMapper
  module Adapters
    class MockAdapter < SqlAdapter
      COLUMN_QUOTING_CHARACTER = "`"
      TABLE_QUOTING_CHARACTER = "`"
      
      def delete(instance_or_klass, options = nil)
      end
      
      def save(session, instance)
      end
      
      def load(session, klass, options)
      end
      
      def table_exists?(name)
        true
      end
      
    end
  end
end