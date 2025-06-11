# app/models/user_suspension.rb
# 사용자 계정 정지 관리 및 정지 만료 자동화를 위한 모델
class UserSuspension < ApplicationRecord
  belongs_to :user

  # 현재 활성화된 정지 상태인 레코드만 조회
  scope :active, -> { where(active: true) }

  # 현재 시간 기준으로 아직 만료되지 않은 유효한 정지 상태만 조회
  scope :currently_active, -> { active.where("suspended_until > ?", Time.current) }

  # 정지 기간이 만료되었지만 아직 active 플래그가 true인 레코드 조회
  scope :expired, -> { active.where("suspended_until <= ?", Time.current) }

  # 필요한 Validation 추가
  validates :suspended_at, presence: true
  validates :suspended_until, presence: true
  validates :reason, presence: true

  # 사용자가 현재 정지 상태인지 확인
  def self.currently_suspended?(user_id)
    currently_active.where(user_id: user_id).exists?
  end

  # 정지 만료 처리 (배치 작업용)
  def self.process_expired_suspensions
    count = 0

    # 만료된 정지를 가져와서 처리
    expired.find_each do |suspension|
      # 정지 비활성화
      suspension.update(active: false)

      # 해당 사용자의 활성 정지가 더 이상 없는 경우에만 차단 해제
      unless currently_suspended?(suspension.user_id)
        suspension.user.update(blocked: false)

        # 정지 해제 알림 발송 (NotificationWorker 있는 경우)
        if defined?(NotificationWorker)
          NotificationWorker.perform_async(
            suspension.user_id,
            "suspension_ended",
            "계정 정지 해제 알림",
            "귀하의 계정 정지가 해제되었습니다. Talkk 서비스를 다시 이용하실 수 있습니다.",
            { suspension_id: suspension.id }
          )
        end
      end

      count += 1
    end

    # 처리된 건수 반환
    count
  end

  # 정지 남은 시간 계산
  def time_remaining
    return 0 unless active?

    remaining = suspended_until - Time.current
    remaining.positive? ? remaining : 0
  end
end
