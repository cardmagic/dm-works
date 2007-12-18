class User #< DataMapper::Base
  include DataMapper::Persistence
  
  property :name, :string
  has_many :comments, :class => 'Comment', :foreign_key => 'user_id'
end