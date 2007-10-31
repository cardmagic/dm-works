require File.dirname(__FILE__) + "/spec_helper"

describe DataObject do
  
  it "should return an empty reader" do
    database.adapter.connection do |connection|
      command = connection.create_command('SELECT `id`, `name` FROM `zoos` WHERE (`id` IS NULL)')

      command.execute_reader do |reader|
        reader.has_rows?.should == false
  
        # reader.each do
        #   reader.current_row.should be_nil
        # end
      end
    end
  end
  
  it "should also return an empty reader when it is used by itself" do
    DataObject::Mysql::Connection.new("dbname=data_mapper_1 socket=/tmp/mysql.sock user=root") do |db|
      cmd = db.create_command('SELECT `id`, `name` FROM `zoos` WHERE (`id` IS NULL)')
      r = cmd.execute_reader do |reader|
        r.has_rows?.should == false
      end
    end
  end
  
end