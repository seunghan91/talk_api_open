class Session < ApplicationRecord
  belongs_to :user
  has_secure_token

  scope :active, -> { where("last_active_at > ?", 30.days.ago) }

  def expired?
    last_active_at < 30.days.ago
  end

  def touch_last_active!
    update_column(:last_active_at, Time.current)
  end
end
