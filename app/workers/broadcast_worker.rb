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

      # 송신자 정보
      sender = broadcast.user
      Rails.logger.info("브로드캐스트 송신자: ID #{sender.id}, 닉네임 #{sender.nickname}")

      # 무작위 수신자 선택 - 활성 상태 사용자만 대상으로 함
      recipients = User.where.not(id: broadcast.user_id)
                       .where(status: :active)  # 활성 상태인 사용자만
                       .where.not(phone_number: nil)  # 전화번호가 있는 사용자만
                       .order("RANDOM()")
                       .limit(recipient_count)

      # 수신자 로깅
      recipient_ids = recipients.pluck(:id).join(', ')
      Rails.logger.info("브로드캐스트 수신자 선택 완료: #{recipients.count}명, IDs: [#{recipient_ids}]")

      # 브로드캐스트 수신자로 설정
      broadcast_recipients = []
      
      recipients.each do |recipient|
        # 수신자 정보 로깅
        Rails.logger.info("수신자 정보: ID #{recipient.id}, 닉네임 #{recipient.nickname}, 상태 #{recipient.status}")
        
        # 브로드캐스트 수신자 생성
        broadcast_recipient = BroadcastRecipient.create(
          broadcast: broadcast,
          user: recipient,
          status: :delivered
        )
        
        # 생성 결과 로깅
        if broadcast_recipient.persisted?
          Rails.logger.info("브로드캐스트 수신자 생성 성공: ID #{broadcast_recipient.id}")
          broadcast_recipients << broadcast_recipient
        else
          Rails.logger.error("브로드캐스트 수신자 생성 실패: 수신자 ID #{recipient.id}, 오류: #{broadcast_recipient.errors.full_messages.join(', ')}")
        end
      end

      # 브로드캐스트 수신자와 대화 자동 생성 확인
      broadcast_recipients.each do |br|
        # 대화 찾기
        conversation = Conversation.where(
          "user_a_id = ? AND user_b_id = ? OR user_a_id = ? AND user_b_id = ?",
          broadcast.user_id, br.user_id, br.user_id, broadcast.user_id
        ).first
        
        if conversation
          Rails.logger.info("브로드캐스트 수신자 (ID #{br.user_id})와 대화가 이미 존재함: ID #{conversation.id}")
          
          # 대화에 브로드캐스트 메시지 추가
          message = Message.find_or_create_by(
            conversation: conversation,
            sender_id: broadcast.user_id,
            broadcast_id: broadcast.id
          )
          
          if message.persisted?
            Rails.logger.info("대화에 브로드캐스트 메시지 추가 성공: 메시지 ID #{message.id}")
          else
            Rails.logger.error("대화에 브로드캐스트 메시지 추가 실패: #{message.errors.full_messages.join(', ')}")
          end
        else
          Rails.logger.error("브로드캐스트 수신자 (ID #{br.user_id})와 대화를 찾을 수 없음, 대화 자동 생성 로직 확인 필요")
          
          # 대화 생성 시도
          conversation = Conversation.create(
            user_a_id: [broadcast.user_id, br.user_id].min,
            user_b_id: [broadcast.user_id, br.user_id].max
          )
          
          if conversation.persisted?
            Rails.logger.info("대화 자동 생성 성공: ID #{conversation.id}")
            
            # 대화에 브로드캐스트 메시지 추가
            message = Message.create(
              conversation: conversation,
              sender_id: broadcast.user_id,
              broadcast_id: broadcast.id
            )
            
            if message.persisted?
              Rails.logger.info("대화에 브로드캐스트 메시지 추가 성공: 메시지 ID #{message.id}")
            else
              Rails.logger.error("대화에 브로드캐스트 메시지 추가 실패: #{message.errors.full_messages.join(', ')}")
            end
          else
            Rails.logger.error("대화 자동 생성 실패: #{conversation.errors.full_messages.join(', ')}")
          end
        end
      end

      # 푸시 알림 전송
      recipients.each do |recipient|
        next unless recipient.broadcast_push_enabled && recipient.push_token.present?

        begin
          PushNotificationService.new.send_broadcast_notification(
            recipient,
            broadcast
          )
          Rails.logger.info("푸시 알림 전송 성공: 수신자 ID #{recipient.id}")
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
