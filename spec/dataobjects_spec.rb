describe DataObject do
  
  it "should return an empty reader" do
    # database.adapter.connection do |connection|
    #       command = connection.create_command('SELECT `id`, `name` FROM `zoos` WHERE (`id` IS NULL)')
    #       database.log.debug { "it should return an empty reader" }
    #       database.log.debug { command.text }
    #       begin
    #         reader = command.execute_reader
    #         # reader.has_rows?.should eql(false)
    #       
    #         reader.each do
    #           row = reader.current_row
    #           database.log.debug { "row => #{row.inspect}" }
    #           # row.should be_nil
    #         end
    #       ensure
    #         database.log.debug { connection.open_readers.inspect }
    #         reader.close
    #       end
    #     end
  end
  
end