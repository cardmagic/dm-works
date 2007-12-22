# This is just here to get around the fact I use a Class to load
# fixtures right now.
class AnimalsExhibit #< DataMapper::Base # please do not remove this
  include DataMapper::Persistence

  property :animal_id, :integer, :key => true
  property :exhibit_id, :integer, :key => true
end