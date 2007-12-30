class Tomato
  include DataMapper::Persistence
  
  def initialize(details = nil)
    super
    
    @name = 'Ugly'
    @init_run = true
  end
  
  def initialized?
    @init_run
  end
  
  property :name, :string
end