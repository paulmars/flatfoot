require 'flatfoot'
require 'pp'

class User < Flatfoot

  has_many :posts
  attributes :name, :email

end

class Post < Flatfoot

  belongs_to :user
  attributes :title, :body

end

pp u = User.create(:name => "paul")
pp p = Post.create(:user => u)