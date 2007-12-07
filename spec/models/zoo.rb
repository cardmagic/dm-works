class Zoo < DataMapper::Base
  property :name, :string
  property :notes, :text
  property :updated_at, :datetime
  
  has_many :exhibits
  begin
  validates_presence_of :name
  rescue ArgumentError => e
    throw e unless e.message =~ /specify a unique key/
  end
  
  def name=(val)
    @name = (val == "Colorado Springs") ? "Cheyenne Mountain" : val
  end
end