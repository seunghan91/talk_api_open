# app/commands/broadcasts/reply_to_broadcast_command.rb
module Broadcasts
  class ReplyToBroadcastCommand
    def initialize(user:, broadcast_id:, voice_file:,
                   broadcast_repository: nil, notification_service: nil)
      @user = user
      @broadcast_id = broadcast_id
      @voice_file = voice_file

      # 의존성 주입 (DIP)
      @broadcast_repository = broadcast_repository || BroadcastRepository.new
      @notification_service = notification_service || NotificationService.new
    end

    def execute
      validate_params!
      
      broadcast = find_broadcast!
      check_permission!(broadcast)
      
      conversation = find_or_create_conversation(broadcast)
      message = create_reply_message(conversation)
      update_broadcast_status(broadcast)
      send_notification(broadcast)
      
      {
        success: true,
        conversation_id: conversation.id,
        message_id: message.id,
        recipient: serialize_recipient(broadcast.user)
      }
    rescue CommandError => e
      e.to_h.merge(success: false)
    rescue => e
      Rails.logger.error("브로드캐스트 답장 실패: #{e.message}")
      { success: false, error: "답장 처리 중 오류가 발생했습니다.", status: :internal_server_error }
    end

    private

    def validate_params!
      unless @voice_file.present?
        raise CommandError.new(
          error: "음성 파일이 필요합니다.",
          status: :bad_request
        )
      end
      
      # 파일 크기 검증
      if @voice_file.size > 10.megabytes
        raise CommandError.new(
          error: "음성 파일이 너무 큽니다. (최대 10MB)",
          status: :bad_request
        )
      end
    end

    def find_broadcast!
      broadcast = @broadcast_repository.find_by_id(@broadcast_id)
      
      unless broadcast
        raise CommandError.new(
          error: "브로드캐스트를 찾을 수 없습니다.",
          status: :not_found
        )
      end
      
      broadcast
    end

    def check_permission!(broadcast)
      # 수신자인지 확인
      recipient = BroadcastRecipient.find_by(
        broadcast_id: broadcast.id,
        user_id: @user.id
      )
      
      unless recipient
        raise CommandError.new(
          error: "이 브로드캐스트에 답장할 권한이 없습니다.",
          status: :forbidden
        )
      end
      
      # 이미 답장한 경우
      if recipient.status == "replied"
        raise CommandError.new(
          error: "이미 답장한 브로드캐스트입니다.",
          status: :unprocessable_entity
        )
      end
    end

    def find_or_create_conversation(broadcast)
      ActiveRecord::Base.transaction do
        # 기존 대화 찾기
        conversation = Conversation.between_users(@user.id, broadcast.user_id).first
        
        # 없으면 생성
        unless conversation
          conversation = Conversation.find_or_create_conversation(
            @user.id, 
            broadcast.user_id
          )
        end
        
        # 답장하는 사용자에게 대화방이 보이도록 설정
        conversation.show_to!(@user.id)
        
        conversation
      end
    end

    def create_reply_message(conversation)
      message = conversation.messages.build(
        sender_id: @user.id,
        message_type: "voice",
        broadcast_id: @broadcast_id
      )
      
      # 음성 파일 첨부
      message.voice_file.attach(@voice_file)
      
      unless message.save
        raise CommandError.new(
          error: "메시지 생성에 실패했습니다.",
          errors: message.errors.full_messages,
          status: :unprocessable_entity
        )
      end
      
      Rails.logger.info("브로드캐스트 답장 메시지 생성: ID #{message.id}")
      
      message
    end

    def update_broadcast_status(broadcast)
      @broadcast_repository.update_recipient_status(
        broadcast.id,
        @user.id,
        :replied
      )
    end

    def send_notification(broadcast)
      @notification_service.send_broadcast_reply_notification(
        sender: @user,
        recipient: broadcast.user,
        broadcast: broadcast
      )
    rescue => e
      # 알림 전송 실패는 전체 프로세스를 중단시키지 않음
      Rails.logger.error("알림 전송 실패: #{e.message}")
    end

    def serialize_recipient(user)
      {
        id: user.id,
        nickname: user.nickname
      }
    end

    # 커스텀 에러 클래스
    class CommandError < StandardError
      attr_reader :error, :errors, :status, :extra

      def initialize(error:, errors: nil, status: :unprocessable_entity, **extra)
        @error = error
        @errors = errors
        @status = status
        @extra = extra
        super(error)
      end

      def to_h
        { error: error, errors: errors, status: status }.merge(extra).compact
      end
    end
  end
end 