# This is just here to get around the fact I use a Class to load
# fixtures right now.
class AnimalsExhibit < DataMapper::Base
  property :animal_id, :integer, :key => true, :serial => false
  property :exhibit_id, :integer
end