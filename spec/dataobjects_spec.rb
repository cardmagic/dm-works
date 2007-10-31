require File.dirname(__FILE__) + "/spec_helper"

describe DataObject do
  
  it "should return an empty reader" do
    database.adapter.connection do |connection|
      command = connection.create_command('SELECT `id`, `name` FROM `zoos` WHERE (`id` IS NULL)')

      command.execute_reader do |reader|
        reader.has_rows?.should eql(false)
  
        reader.each do
          reader.current_row.should be_nil
        end
      end
    end
  end
  
end