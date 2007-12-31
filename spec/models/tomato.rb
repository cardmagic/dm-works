class Tomato
  include DataMapper::Persistence
  
  ATTRIBUTES << :bruised
  
  def initialize(details = nil)
    super
    
    @name = 'Ugly'
    @init_run = true
    @bruised = false
  end
  
  def initialized?
    @init_run
  end
  
  property :name, :string
  
  def bruised?
    @bruised
  end
end