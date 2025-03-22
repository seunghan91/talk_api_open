class BroadcastWorker
  include Sidekiq::Worker
  sidekiq_options queue: :broadcasts, retry: 3

  def perform(broadcast_id, recipient_count = 5)
    begin
      Rails.logger.info("브로드캐스트 처리 시작: ID #{broadcast_id}, 수신자 수 #{recipient_count}")

      broadcast = Broadcast.find_by(id: broadcast_id)
      unless broadcast
        Rails.logger.error("브로드캐스트를 찾을 수 없음: ID #{broadcast_id}")
        return
      end

      # 무작위 수신자 선택
      recipients = User.where.not(id: broadcast.user_id)
                      .where(status: :active)
                      .order("RANDOM()")
                      .limit(recipient_count)

      Rails.logger.info("브로드캐스트 수신자 선택 완료: #{recipients.count}명")

      # 브로드캐스트 수신자로 설정
      broadcast_recipients = []
      recipients.each do |recipient|
        broadcast_recipients << BroadcastRecipient.create(
          broadcast: broadcast,
          user: recipient,
          status: :delivered
        )
      end

      # 푸시 알림 전송
      recipients.each do |recipient|
        next unless recipient.broadcast_push_enabled && recipient.push_token.present?

        begin
          PushNotificationService.new.send_broadcast_notification(
            recipient,
            broadcast
          )
        rescue => e
          Rails.logger.error("푸시 알림 전송 실패 (수신자: #{recipient.id}): #{e.message}")
        end
      end

      Rails.logger.info("브로드캐스트 처리 완료: ID #{broadcast_id}")
    rescue Redis::CannotConnectError, RedisClient::CannotConnectError => e
      Rails.logger.error("Redis 연결 실패: #{e.message}")
      raise e
    rescue => e
      Rails.logger.error("브로드캐스트 처리 실패: #{e.message}\n#{e.backtrace.join("\n")}")
      raise e
    end
  end
end
