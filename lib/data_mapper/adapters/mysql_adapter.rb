require 'data_mapper/adapters/data_object_adapter'
begin
  require 'do_mysql'
rescue
  STDERR.puts <<-EOS
You must install the DataObjects::Mysql driver.
  rake dm:install:mysql
EOS
  exit
end

module DataMapper
  module Adapters
    
    class MysqlAdapter < DataObjectAdapter
      def create_connection
        
        connection_string = ""
        builder = lambda { |k,v| connection_string << "#{k}=#{@configuration.send(v)}" if @configuration.send(v) }
        
        builder['host', :host]
        builder['user', :username]
        builder['password', :password]
        builder['dbname', :database]
        
        conn = DataObject::Mysql::Connection.new(connection_string)
        conn.open
        cmd = conn.create_command("SET NAMES UTF8")
        cmd.execute_non_query
        return conn
      end
      
      module Mappings
        
        def to_create_table_sql
          @to_create_table_sql || @to_create_table_sql = begin
            "CREATE TABLE #{to_sql} (#{columns.map { |c| c.to_long_form }.join(', ')}) Type=MyISAM CHARACTER SET utf8"
          end
        end
        
      end # module Mappings
    end # class MysqlAdapter
    
  end # module Adapters
end # module DataMapper