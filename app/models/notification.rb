class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :body, presence: true
  validates :notification_type, presence: true,
            inclusion: { in: %w[message broadcast system] }

  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc) }

  # 타입별 스코프
  scope :messages, -> { where(notification_type: "message") }
  scope :broadcasts, -> { where(notification_type: "broadcast") }
  scope :system, -> { where(notification_type: "system") }

  # 알림을 읽음 처리
  def mark_as_read!
    update(read: true)
  end

  # 푸시 알림 전송 (앱에서 호출)
  def send_push!
    return unless user.push_enabled
    return if user.push_token.blank?

    # 푸시 알림 타입 기반 설정 확인
    case notification_type
    when "message"
      return unless user.message_push_enabled
    when "broadcast"
      return unless user.broadcast_push_enabled
    end

    # Expo 푸시 알림 서비스로 전송
    # 실제 구현에서는 Exponent::Push 같은 젬을 사용하거나 HTTP 클라이언트로 직접 구현
    PushNotificationService.send_notification(
      user.push_token,
      title: title.presence || notification_type_to_korean,
      body: body,
      data: {
        notification_id: id,
        notification_type: notification_type,
        metadata: metadata
      }
    )
  end

  private

  def notification_type_to_korean
    case notification_type
    when "message" then "새 메시지"
    when "broadcast" then "새 방송"
    when "system" then "시스템 알림"
    else "알림"
    end
  end
end
