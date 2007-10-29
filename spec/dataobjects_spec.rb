describe DataObject do
  
  it "should return an empty reader" do
    database.adapter.connection do |connection|
      command = connection.create_command('SELECT `id`, `name`, `updated_at` FROM `zoos` WHERE (`id` IS NULL)')
      reader = command.execute_reader
      reader.has_rows.should eql(false)
      
      reader.each do
        reader.current_row.should be_nil
      end
      
      reader.close
    end
  end
  
end
