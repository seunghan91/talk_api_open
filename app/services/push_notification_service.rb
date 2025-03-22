# app/services/push_notification_service.rb
require "net/http"
require "uri"
require "json"

class PushNotificationService
  # Expo Push Notification 서비스 URL
  EXPO_PUSH_URL = "https://exp.host/--/api/v2/push/send".freeze

  # 푸시 알림 전송
  def self.send_notification(push_token, title:, body:, data: {})
    return if push_token.blank?

    # Expo 푸시 서비스에 전송할 데이터 구성
    message = {
      to: push_token,
      title: title,
      body: body,
      data: data,
      sound: "default",
      badge: 1, # iOS 뱃지 카운터
      channelId: "default", # Android 채널 ID
      priority: "high" # Android 우선순위
    }

    # 개발 모드에서는 로깅만 수행
    if Rails.env.development? || Rails.env.test?
      Rails.logger.info "[PushNotification] Would send: #{message.to_json}"
      return true
    end

    # 실제 Expo 푸시 서비스 호출
    begin
      uri = URI.parse(EXPO_PUSH_URL)
      request = Net::HTTP::Post.new(
        uri.request_uri,
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      )
      request.body = [ message ].to_json

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      # 응답 처리
      result = JSON.parse(response.body)
      if result["data"].present? && result["data"][0]["status"] == "ok"
        Rails.logger.info "[PushNotification] Successfully sent to #{push_token}"
        true
      else
        Rails.logger.error "[PushNotification] Failed: #{result.to_json}"
        false
      end

    rescue => e
      Rails.logger.error "[PushNotification] Error: #{e.message}"
      false
    end
  end

  # 여러 토큰에 동시에 알림 전송
  def self.send_notifications(push_tokens, title:, body:, data: {})
    # 빈 토큰 제거
    tokens = Array(push_tokens).compact.reject(&:blank?)
    return if tokens.empty?

    # 최대 100개씩 나누어 전송 (Expo API 제한)
    tokens.each_slice(100) do |token_batch|
      messages = token_batch.map do |token|
        {
          to: token,
          title: title,
          body: body,
          data: data,
          sound: "default",
          badge: 1,
          channelId: "default",
          priority: "high"
        }
      end

      # 개발 모드에서는 로깅만 수행
      if Rails.env.development? || Rails.env.test?
        Rails.logger.info "[PushNotification] Would send to #{token_batch.size} devices: #{messages.to_json}"
        next
      end

      # 실제 Expo 푸시 서비스 호출
      begin
        uri = URI.parse(EXPO_PUSH_URL)
        request = Net::HTTP::Post.new(
          uri.request_uri,
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        )
        request.body = messages.to_json

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        # 결과 로깅
        result = JSON.parse(response.body)
        Rails.logger.info "[PushNotification] Batch result: #{result.to_json}"

      rescue => e
        Rails.logger.error "[PushNotification] Batch error: #{e.message}"
      end
    end
  end

  # 브로드캐스트 답장 알림
  def send_broadcast_reply_notification(broadcast, sender)
    return unless broadcast.user.expo_push_token.present?

    send_notification(
      broadcast.user.expo_push_token,
      title: "브로드캐스트 답장",
      body: "#{sender.nickname}님이 당신의 브로드캐스트에 답장했습니다.",
      data: {
        type: "broadcast_reply",
        broadcast_id: broadcast.id,
        sender_id: sender.id,
        sender_nickname: sender.nickname
      }
    )
  end

  # 새 메시지 알림
  def send_new_message_notification(message)
    conversation = message.conversation
    sender = message.sender

    # 수신자 결정
    receiver_id = (conversation.user_a_id == sender.id) ? conversation.user_b_id : conversation.user_a_id
    receiver = User.find_by(id: receiver_id)

    return unless receiver&.expo_push_token.present?

    send_notification(
      receiver.expo_push_token,
      title: "새 메시지",
      body: "#{sender.nickname}님으로부터 새 메시지가 도착했습니다.",
      data: {
        type: "new_message",
        conversation_id: conversation.id,
        sender_id: sender.id,
        sender_nickname: sender.nickname
      }
    )
  end

  # 사용자 정지 알림
  def send_suspension_notification(user, reason = nil)
    return unless user.expo_push_token.present?

    message = reason.present? ? "계정이 정지되었습니다. 사유: #{reason}" : "계정이 정지되었습니다."

    send_notification(
      user.expo_push_token,
      title: "계정 정지 알림",
      body: message,
      data: {
        type: "account_suspension",
        reason: reason
      }
    )
  end

  # 새 브로드캐스트 알림 (설정에 따라 전송)
  def send_new_broadcast_notification(broadcast, recipients)
    return if recipients.empty?

    # 푸시 알림 설정이 켜져 있는 사용자만 필터링
    valid_recipients = recipients.select { |user| user.expo_push_token.present? && user.push_enabled? }
    return if valid_recipients.empty?

    tokens = valid_recipients.map(&:expo_push_token)

    send_notification(
      tokens,
      title: "새 브로드캐스트",
      body: "#{broadcast.user.nickname}님이 새 브로드캐스트를 게시했습니다.",
      data: {
        type: "new_broadcast",
        broadcast_id: broadcast.id,
        user_id: broadcast.user.id,
        user_nickname: broadcast.user.nickname
      }
    )
  end

  private

  # Expo 푸시 토큰 유효성 검사
  def valid_expo_token?(token)
    token.present? && token.start_with?("ExponentPushToken[")
  end
end
