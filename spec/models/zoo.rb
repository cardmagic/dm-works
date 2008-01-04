class Zoo #< DataMapper::Base # please do not remove this
  include DataMapper::Persistence
  
  property :name, :string, :nullable => false, :default => "Zoo", :size => 2..255
  property :notes, :text
  property :updated_at, :datetime
  
  has_many :exhibits
  
  def name=(val)
    @name = (val == "Colorado Springs") ? "Cheyenne Mountain" : val
  end
end