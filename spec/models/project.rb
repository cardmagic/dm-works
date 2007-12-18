class Project #< DataMapper::Base
  include DataMapper::Persistence
  
  property :title, :string
  property :description, :string

  has_many :sections
  
  before_create :create_main_section
  
  def tickets
    return [] if sections.empty?
    sections.map { |section| section.tickets }
  end
  
  private
  
  def create_main_section
    sections << Section.find_or_create(:title => "Main") if sections.empty?
  end
end