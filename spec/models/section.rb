class Section #< DataMapper::Base
  include DataMapper::Persistence
  
  property :title, :string
  property :created_at, :datetime
  
  belongs_to :project
end