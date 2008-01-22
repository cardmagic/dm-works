class Candidate < DataMapper::Base
  property :name, :string
  
  belongs_to :job
  has_and_belongs_to_many :applications, :class => 'Job'
end