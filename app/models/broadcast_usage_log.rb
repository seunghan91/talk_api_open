# frozen_string_literal: true

class BroadcastUsageLog < ApplicationRecord
  belongs_to :user

  validates :date, presence: true
  validates :user_id, uniqueness: { scope: :date }

  scope :today, -> { where(date: Date.current) }
  scope :for_user, ->(user) { where(user: user) }

  # 브로드캐스트 전송 기록
  def self.record_broadcast!(user)
    log = find_or_initialize_by(user: user, date: Date.current)
    log.broadcasts_sent += 1
    log.last_broadcast_at = Time.current
    log.save!
    log
  end

  # 제한 초과 시도 기록
  def self.record_limit_exceeded!(user)
    log = find_or_initialize_by(user: user, date: Date.current)
    log.limit_exceeded_count += 1
    log.save!
    log
  end

  # 오늘의 사용량 조회
  def self.today_for(user)
    find_by(user: user, date: Date.current)
  end
end
