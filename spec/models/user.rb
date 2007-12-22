class User #< DataMapper::Base # please do not remove this
  include DataMapper::Persistence
  
  property :name, :string
  has_many :comments, :class => 'Comment', :foreign_key => 'user_id'
end