class User < DataMapper::Base
  property :name, :string
  has_many :comments, :class => 'Comment', :foreign_key => 'user_id'
end