# app/services/push_notification_service.rb
require "net/http"
require "uri"
require "json"

class PushNotificationService
  # FCM HTTP v1 API endpoint
  FCM_URL = "https://fcm.googleapis.com/v1/projects/%s/messages:send".freeze
  FCM_SCOPE = "https://www.googleapis.com/auth/firebase.cloud-messaging".freeze

  class << self
    # Send push notification to a single device
    def send_notification(push_token, title:, body:, data: {})
      return if push_token.blank?

      message = build_message(push_token, title: title, body: body, data: data)

      if Rails.env.development? || Rails.env.test?
        Rails.logger.info "[FCM] Would send: #{message.to_json}"
        return true
      end

      send_fcm_request(message)
    end

    # Send push notification to multiple devices
    def send_notifications(push_tokens, title:, body:, data: {})
      tokens = Array(push_tokens).compact.reject(&:blank?)
      return if tokens.empty?

      # FCM v1 doesn't support batch to multiple tokens in one request
      # Send individually (could use topic messaging for large batches)
      tokens.each do |token|
        send_notification(token, title: title, body: body, data: data)
      end
    end

    private

    def build_message(token, title:, body:, data: {})
      {
        message: {
          token: token,
          notification: {
            title: title,
            body: body
          },
          data: data.transform_keys(&:to_s).transform_values(&:to_s),
          android: {
            priority: "high",
            notification: {
              channel_id: "talkk_messages",
              sound: "default",
              default_vibrate_timings: true,
              notification_priority: "PRIORITY_HIGH"
            }
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
                "content-available": 1
              }
            },
            headers: {
              "apns-priority": "10"
            }
          }
        }
      }
    end

    def send_fcm_request(message)
      project_id = fcm_project_id
      url = format(FCM_URL, project_id)
      uri = URI.parse(url)

      request = Net::HTTP::Post.new(
        uri.request_uri,
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{access_token}"
      )
      request.body = message.to_json

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code.to_i == 200
        Rails.logger.info "[FCM] Successfully sent notification"
        true
      else
        result = JSON.parse(response.body) rescue {}
        Rails.logger.error "[FCM] Failed (#{response.code}): #{result}"

        # Handle invalid/expired token
        if result.dig("error", "details")&.any? { |d| d["errorCode"] == "UNREGISTERED" }
          Rails.logger.warn "[FCM] Token is unregistered, should be removed"
        end

        false
      end
    rescue => e
      Rails.logger.error "[FCM] Error: #{e.message}"
      false
    end

    def access_token
      @authorizer ||= begin
        Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(service_account_json),
          scope: FCM_SCOPE
        )
      end
      @authorizer.fetch_access_token!
      @authorizer.access_token
    end

    def fcm_project_id
      @fcm_project_id ||= JSON.parse(service_account_json)["project_id"]
    end

    # Load service account JSON from env var (production) or file (local)
    def service_account_json
      @service_account_json ||=
        if ENV["FIREBASE_SERVICE_ACCOUNT_JSON"].present?
          ENV["FIREBASE_SERVICE_ACCOUNT_JSON"]
        else
          creds_path = ENV.fetch("GOOGLE_APPLICATION_CREDENTIALS") {
            Rails.root.join("config", "firebase-service-account.json").to_s
          }
          File.read(creds_path)
        end
    end
  end

  # Instance methods for backward compatibility with existing callers

  def send_broadcast_reply_notification(broadcast, sender)
    return unless broadcast.user.push_token.present?

    self.class.send_notification(
      broadcast.user.push_token,
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

  def send_new_message_notification(message)
    conversation = message.conversation
    sender = message.sender

    receiver_id = (conversation.user_a_id == sender.id) ? conversation.user_b_id : conversation.user_a_id
    receiver = User.find_by(id: receiver_id)

    return unless receiver&.push_token.present?

    self.class.send_notification(
      receiver.push_token,
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

  def send_suspension_notification(user, reason = nil)
    return unless user.push_token.present?

    msg = reason.present? ? "계정이 정지되었습니다. 사유: #{reason}" : "계정이 정지되었습니다."

    self.class.send_notification(
      user.push_token,
      title: "계정 정지 알림",
      body: msg,
      data: {
        type: "account_suspension",
        reason: reason
      }
    )
  end

  def send_new_broadcast_notification(broadcast, recipients)
    return if recipients.empty?

    valid_recipients = recipients.select { |user| user.push_token.present? && user.push_enabled? }
    return if valid_recipients.empty?

    tokens = valid_recipients.map(&:push_token)
    self.class.send_notifications(
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
end
