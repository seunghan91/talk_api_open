# app/services/notification_service.rb
class NotificationService
  # Result 객체 패턴
  class Result
    attr_reader :success, :sent_count, :errors

    def initialize(success:, sent_count: 0, errors: [])
      @success = success
      @sent_count = sent_count
      @errors = errors
    end

    def success?
      @success
    end
  end

  # FCM adapter that wraps PushNotificationService with send_messages interface
  # for backward compatibility with dependency injection in tests
  class FcmPushClient
    def send_messages(messages)
      messages.each do |msg|
        PushNotificationService.send_notification(
          msg[:to],
          title: msg[:title],
          body: msg[:body],
          data: msg[:data] || {}
        )
      end
    end
  end

  def initialize(push_client: nil)
    @push_client = push_client || FcmPushClient.new
  end

  def send_notification(user:, type:, title:, body:, data: {})
    # 알림 기록 생성
    notification = create_notification_record(user, type, title, body, data)

    # 푸시 알림 전송 (조건 충족 시)
    if should_send_push?(user, type)
      send_push_notification(user, title, body, data)
    end

    Result.new(success: true, sent_count: 1)
  rescue => e
    Rails.logger.error("알림 전송 실패: #{e.message}")
    Result.new(success: false, errors: [ e.message ])
  end

  def send_welcome_notification(user)
    send_notification(
      user: user,
      type: :system,
      title: "환영합니다!",
      body: "#{user.nickname}님, Talkk에 오신 것을 환영합니다!",
      data: { type: "welcome" }
    )
  rescue => e
    # 환영 알림 실패는 회원가입을 막지 않음
    Rails.logger.warn("환영 알림 전송 실패: #{e.message}")
    Result.new(success: false, errors: [e.message])
  end

  def send_broadcast_notification(user, broadcast)
    return Result.new(success: true) unless user.broadcast_push_enabled

    strategy = BroadcastStrategy.new
    title = strategy.format_title(broadcast)
    body = strategy.format_body(broadcast)
    data = strategy.format_data(broadcast)

    send_notification(
      user: user,
      type: :broadcast,
      title: title,
      body: body,
      data: data
    )
  end

  def send_message_notification(user, message)
    return Result.new(success: true) unless user.message_push_enabled

    strategy = MessageStrategy.new
    title = strategy.format_title(message)
    body = strategy.format_body(message)
    data = strategy.format_data(message)

    send_notification(
      user: user,
      type: :message,
      title: title,
      body: body,
      data: data
    )
  end

  def send_bulk_notifications(users:, type:, title:, body:, data: {})
    sent_count = 0
    errors = []

    # 푸시 토큰이 있는 사용자 필터링
    eligible_users = users.select { |u| should_send_push?(u, type) }

    # 알림 기록 일괄 생성
    notifications = users.map do |user|
      {
        user_id: user.id,
        notification_type: type.to_s,
        title: title,
        body: body,
        metadata: data,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    Notification.insert_all(notifications)

    # 푸시 알림 일괄 전송
    if eligible_users.any?
      messages = eligible_users.map do |user|
        {
          to: user.push_token,
          title: title,
          body: body,
          data: data,
          sound: "default",
          badge: 1
        }
      end

      begin
        @push_client.send_messages(messages)
        sent_count = eligible_users.count
      rescue => e
        errors << e.message
      end
    end

    Result.new(
      success: errors.empty?,
      sent_count: sent_count,
      errors: errors
    )
  end

  private

  def should_send_push?(user, type)
    return false unless user.push_enabled && user.push_token.present?

    case type.to_sym
    when :broadcast
      user.broadcast_push_enabled
    when :message
      user.message_push_enabled
    else
      true
    end
  end

  def create_notification_record(user, type, title, body, data)
    user.notifications.create!(
      notification_type: type.to_s,
      title: title,
      body: body,
      metadata: data
    )
  end

  def send_push_notification(user, title, body, data)
    message = {
      to: user.push_token,
      title: title,
      body: body,
      data: data,
      sound: "default",
      badge: 1
    }

    @push_client.send_messages([ message ])
  rescue => e
    Rails.logger.error("푸시 알림 전송 실패 (user: #{user.id}): #{e.message}")
    raise e
  end

  # Strategy 패턴 구현
  class NotificationStrategy
    def format_title(object)
      raise NotImplementedError
    end

    def format_body(object)
      raise NotImplementedError
    end

    def format_data(object)
      {}
    end
  end

  class BroadcastStrategy < NotificationStrategy
    def format_title(broadcast)
      "#{broadcast.user.nickname}님의 새로운 브로드캐스트"
    end

    def format_body(broadcast)
      broadcast.content.presence || "새로운 음성 메시지가 도착했습니다"
    end

    def format_data(broadcast)
      {
        broadcast_id: broadcast.id,
        sender_id: broadcast.user_id,
        type: "broadcast"
      }
    end
  end

  class MessageStrategy < NotificationStrategy
    def format_title(message)
      "#{message.sender.nickname}님의 새 메시지"
    end

    def format_body(message)
      "음성 메시지를 보냈습니다"
    end

    def format_data(message)
      {
        message_id: message.id,
        conversation_id: message.conversation_id,
        sender_id: message.sender_id,
        type: "message"
      }
    end
  end

  class AnnouncementStrategy < NotificationStrategy
    def format_title(_)
      "📢 공지사항"
    end

    def format_body(_)
      "중요한 공지사항을 확인해주세요"
    end

    def format_data(_)
      { type: "announcement" }
    end
  end
end
