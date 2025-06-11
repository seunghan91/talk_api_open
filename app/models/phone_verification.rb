# app/models/phone_verification.rb
class PhoneVerification < ApplicationRecord
  validates :phone_number, presence: true
  validates :code, presence: true

  belongs_to :user, optional: true

  # 기본값 설정
  attribute :attempt_count, :integer, default: 0

  # 최대 시도 횟수
  MAX_ATTEMPTS = 5

  def expired?
    Time.current > self.expires_at
  end

  def attempts_exceeded?
    self.attempt_count >= MAX_ATTEMPTS
  end

  def remaining_attempts
    [ MAX_ATTEMPTS - self.attempt_count, 0 ].max
  end

  def increment_attempt!
    self.increment!(:attempt_count)
  end

  def reset_attempts!
    self.update(attempt_count: 0)
  end

  def mark_as_verified!
    self.update!(verified: true, attempt_count: 0)
  end
end
