class Section < DataMapper::Base
  property :title, :string
  property :created_at, :datetime
  
  belongs_to :project
end