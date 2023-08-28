class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :hits

  def count_hits
    start = Time.now.beginning_of_month
    hits = hits.where('created_at > ?', start).count
    return hits
  end
end
