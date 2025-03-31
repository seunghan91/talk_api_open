class AnnouncementCategory < ApplicationRecord
  has_many :announcements, foreign_key: 'category_id', dependent: :destroy
  
  validates :name, presence: true, uniqueness: true
  
  scope :sorted, -> { order(created_at: :desc) }
end
