class Comment #< DataMapper::Base
  include DataMapper::Persistence
  
  property   :comment, :text, :lazy => false
  belongs_to :author, :class => 'User', :foreign_key => 'user_id'
end