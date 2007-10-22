require 'data_mapper/adapters/data_object_adapter'
require 'do_mysql'

module DataMapper
  module Adapters
    
    class MysqlAdapter < DataObjectAdapter
      def create_connection
        conn = DataObject::Mysql::Connection.new("socket=/tmp/mysql.sock user=root dbname=data_mapper_1")
        conn.open
        return conn
      end
    end # class MysqlAdapter
    
  end # module Adapters
end # module DataMapper