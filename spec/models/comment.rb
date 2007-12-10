class Comment < DataMapper::Base
  property   :comment, :text, :lazy => false
  belongs_to :author, :class => 'User', :foreign_key => 'user_id'
end