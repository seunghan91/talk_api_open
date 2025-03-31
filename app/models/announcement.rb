class Announcement < ApplicationRecord
  belongs_to :category, class_name: 'AnnouncementCategory'
  
  validates :title, presence: true
  validates :content, presence: true
  validates :category, presence: true
  
  after_initialize :set_default_values, if: :new_record?
  
  scope :published, -> { where(is_published: true) }
  scope :visible, -> { where(is_hidden: false) }
  scope :sorted, -> { order(created_at: :desc) }
  
  private
  
  def set_default_values
    self.is_important ||= false
    self.is_published ||= true
    self.is_hidden ||= false
    self.published_at ||= Time.current if self.is_published
  end
end
