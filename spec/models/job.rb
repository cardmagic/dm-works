class Job < DataMapper::Base
  property :name, :string
  property :hours, :days, :integer, :default => 0
end