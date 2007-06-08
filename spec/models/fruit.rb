class Fruit < DataMapper::Base
  set_table_name 'fruit'
  property :name, :string, :column => 'fruit_name'
  
  belongs_to :devourer_of_souls, :class => 'Animal', :foreign_key => 'devourer_id'
end