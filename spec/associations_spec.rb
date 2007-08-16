return unless ENV['ADAPTER'].nil? || ENV['ADAPTER'] == 'mysql'

describe DataMapper::Associations::HasManyAssociation do
    
  it "should generate the SQL for a join statement" do
    exhibits_association = database.schema[Zoo].associations.find { |a| a.name == :exhibits }
    
    exhibits_association.to_sql.should == <<-EOS.compress_lines
      JOIN `exhibits` ON `exhibits`.`zoo_id` = `zoos`.`id`
    EOS
  end
  
end

describe DataMapper::Associations::HasOneAssociation do
    
  it "should generate the SQL for a join statement" do
    fruit_association = database.schema[Animal].associations.find { |a| a.name == :favourite_fruit }
    
    fruit_association.to_sql.should == <<-EOS.compress_lines
      JOIN `fruit` ON `fruit`.`devourer_id` = `animals`.`id`
    EOS
  end
  
end

describe DataMapper::Associations::HasAndBelongsToManyAssociation do
  
  it "should generate the SQL for a join statement" do
    animals_association = database.schema[Exhibit].associations.find { |a| a.name == :animals }
    
    animals_association.to_sql.should == <<-EOS.compress_lines
      JOIN `animals_exhibits` ON `animals_exhibits`.`exhibit_id` = `exhibits`.`id`
      JOIN `animals` ON `animals`.`id` = `animals_exhibits`.`animal_id`
    EOS
  end
  
end