class PushNotificationJob < ApplicationJob
  queue_as :notifications
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # 다양한 알림 유형 처리
  def perform(notification_type, *args)
    case notification_type.to_s
    when "message"
      send_message_notification(args[0])
    when "broadcast_reply"
      send_broadcast_reply_notification(args[0], args[1])
    when "suspension"
      send_suspension_notification(args[0], args[1])
    when "new_broadcast"
      send_new_broadcast_notification(args[0])
    else
      Rails.logger.error("알 수 없는 알림 유형: #{notification_type}")
    end
  end

  private

  # 메시지 알림 전송
  def send_message_notification(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    PushNotificationService.new.send_new_message_notification(message)
  end

  # 브로드캐스트 답장 알림 전송
  def send_broadcast_reply_notification(broadcast_id, sender_id)
    broadcast = Broadcast.find_by(id: broadcast_id)
    sender = User.find_by(id: sender_id)
    return unless broadcast && sender

    PushNotificationService.new.send_broadcast_reply_notification(broadcast, sender)
  end

  # 계정 정지 알림 전송
  def send_suspension_notification(user_id, reason = nil)
    user = User.find_by(id: user_id)
    return unless user

    PushNotificationService.new.send_suspension_notification(user, reason)
  end

  # 새 브로드캐스트 알림 전송
  def send_new_broadcast_notification(broadcast_id)
    broadcast = Broadcast.find_by(id: broadcast_id)
    return unless broadcast

    # 알림을 받을 사용자 목록 (예: 모든 활성 사용자)
    recipients = User.active

    PushNotificationService.new.send_new_broadcast_notification(broadcast, recipients)
  end
end
