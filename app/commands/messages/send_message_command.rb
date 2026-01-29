# app/commands/messages/send_message_command.rb
module Messages
  class SendMessageCommand
    def initialize(user:, conversation_id:, voice_file: nil, text: nil,
                   conversation_repository: nil, message_repository: nil, 
                   notification_service: nil, event_publisher: nil)
      @user = user
      @conversation_id = conversation_id
      @voice_file = voice_file
      @text = text
      
      # 의존성 주입 (DIP)
      @conversation_repository = conversation_repository || ConversationRepository.new
      @message_repository = message_repository || MessageRepository.new
      @notification_service = notification_service || NotificationService.new
      @event_publisher = event_publisher || EventPublisher.new
    end

    def execute
      validate_params!
      
      conversation = find_conversation!
      check_permission!(conversation)
      
      message = create_message(conversation)
      update_conversation(conversation)
      send_notification(conversation, message)
      publish_event(message, conversation)
      
      {
        success: true,
        message: serialize_message(message),
        conversation_id: conversation.id
      }
    rescue CommandError => e
      e.to_h.merge(success: false)
    rescue => e
      Rails.logger.error("메시지 전송 실패: #{e.message}")
      { success: false, error: "메시지 전송 중 오류가 발생했습니다.", status: :internal_server_error }
    end

    private

    def validate_params!
      unless @voice_file.present? || @text.present?
        raise CommandError.new(
          error: "음성 파일 또는 텍스트가 필요합니다.",
          status: :bad_request
        )
      end
      
      if @voice_file.present?
        # 파일 크기 검증
        if @voice_file.size > 10.megabytes
          raise CommandError.new(
            error: "파일이 너무 큽니다. (최대 10MB)",
            status: :bad_request
          )
        end
        
        # 파일 형식 검증
        allowed_types = %w[audio/mpeg audio/wav audio/m4a audio/mp4]
        unless allowed_types.include?(@voice_file.content_type)
          raise CommandError.new(
            error: "지원하지 않는 파일 형식입니다.",
            status: :bad_request
          )
        end
      end
    end

    def find_conversation!
      conversation = @conversation_repository.find_by_id(@conversation_id)
      
      unless conversation
        raise CommandError.new(
          error: "대화를 찾을 수 없습니다.",
          status: :not_found
        )
      end
      
      conversation
    end

    def check_permission!(conversation)
      # 대화 참여자인지 확인
      unless conversation.participant?(@user)
        raise CommandError.new(
          error: "이 대화에 메시지를 보낼 권한이 없습니다.",
          status: :forbidden
        )
      end
      
      # 대화가 삭제되었는지 확인
      if conversation.deleted_by?(@user)
        raise CommandError.new(
          error: "삭제된 대화입니다.",
          status: :gone
        )
      end
      
      # 상대방이 나를 차단했는지 확인
      other_user = conversation.other_user(@user)
      if Block.exists?(blocker: other_user, blocked: @user)
        raise CommandError.new(
          error: "메시지를 보낼 수 없습니다.",
          status: :forbidden
        )
      end
    end

    def create_message(conversation)
      ActiveRecord::Base.transaction do
        message = @message_repository.create!(
          conversation: conversation,
          sender: @user,
          message_type: determine_message_type,
          read: false
        )
        
        # 파일 첨부
        if @voice_file.present?
          message.voice_file.attach(@voice_file)
        end
        
        Rails.logger.info("메시지 생성 성공: ID #{message.id}")
        
        message
      end
    end

    def determine_message_type
      @voice_file.present? ? "voice" : "text"
    end

    def update_conversation(conversation)
      # 대화가 숨겨진 상태라면 다시 표시
      conversation.show_to!(@user.id)
      
      # 마지막 활동 시간 업데이트
      conversation.touch
    end

    def send_notification(conversation, message)
      other_user = conversation.other_user(@user)

      # 알림 설정 확인
      return unless other_user.message_push_enabled?

      @notification_service.send_message_notification(other_user, message)
    rescue => e
      # 알림 전송 실패는 전체 프로세스를 중단시키지 않음
      Rails.logger.error("알림 전송 실패: #{e.message}")
    end

    def publish_event(message, conversation)
      @event_publisher.publish(MessageSentEvent.new(
        message: message,
        sender: @user,
        conversation: conversation
      ))
    end

    def serialize_message(message)
      voice_url = nil
      if message.voice_file.attached?
        begin
          voice_url = Rails.application.routes.url_helpers.url_for(message.voice_file)
        rescue ArgumentError
          # In test environment or when host is not configured, return a relative path
          voice_url = Rails.application.routes.url_helpers.rails_blob_path(message.voice_file, only_path: true)
        end
      end

      {
        id: message.id,
        sender_id: message.sender_id,
        message_type: message.message_type,
        text: nil,
        voice_url: voice_url,
        created_at: message.created_at,
        read: message.read
      }
    end

    # 커스텀 에러 클래스
    class CommandError < StandardError
      attr_reader :error, :status, :extra

      def initialize(error:, status: :unprocessable_entity, **extra)
        @error = error
        @status = status
        @extra = extra
        super(error)
      end

      def to_h
        { error: error, status: status }.merge(extra)
      end
    end
  end
end 