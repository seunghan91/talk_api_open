# app/commands/broadcasts/create_broadcast_command.rb
module Broadcasts
  class CreateBroadcastCommand
    def initialize(user:, audio_file:, content: nil, recipient_count: 5,
                   broadcast_repository: nil, recipient_selector: nil, event_publisher: nil)
      @user = user
      @audio_file = audio_file
      @content = content || "새로운 음성 메시지"
      @recipient_count = normalize_recipient_count(recipient_count)
      
      # 의존성 주입 (DIP)
      @broadcast_repository = broadcast_repository || BroadcastRepository.new
      @recipient_selector = recipient_selector || RecipientSelector.new
      @event_publisher = event_publisher || EventPublisher.new
    end

    def execute
      validate_params!
      check_user_eligibility!
      
      broadcast = create_broadcast!
      recipients = select_recipients
      
      # 비동기 처리를 위한 워커 실행
      BroadcastDeliveryJob.perform_later(broadcast.id, recipients.map(&:id))
      
      # 이벤트 발행
      @event_publisher.publish(BroadcastCreatedEvent.new(
        broadcast: broadcast,
        sender: @user,
        recipient_count: recipients.count
      ))
      
      {
        success: true,
        broadcast: serialize_broadcast(broadcast),
        recipient_count: recipients.count
      }
    rescue CommandError => e
      e.to_h.merge(success: false)
    rescue => e
      Rails.logger.error("브로드캐스트 생성 실패: #{e.message}")
      { success: false, error: "브로드캐스트 생성 중 오류가 발생했습니다.", status: :internal_server_error }
    end

    private

    def validate_params!
      unless @audio_file.present?
        raise CommandError.new(
          error: "음성 파일이 필요합니다.",
          status: :bad_request
        )
      end
      
      # 파일 크기 검증 (10MB 제한)
      if @audio_file.size > 10.megabytes
        raise CommandError.new(
          error: "음성 파일이 너무 큽니다. (최대 10MB)",
          status: :bad_request
        )
      end
      
      # 파일 형식 검증
      allowed_types = %w[audio/mpeg audio/wav audio/m4a audio/mp4]
      unless allowed_types.include?(@audio_file.content_type)
        raise CommandError.new(
          error: "지원하지 않는 파일 형식입니다.",
          status: :bad_request
        )
      end
    end

    def check_user_eligibility!
      # 사용자 상태 확인
      unless @user.status_active?
        raise CommandError.new(
          error: "현재 계정 상태로는 브로드캐스트를 보낼 수 없습니다.",
          status: :forbidden
        )
      end
      
      # 일일 한도 확인
      daily_count = @broadcast_repository.count_today_by_user(@user)
      if daily_count >= daily_limit
        raise CommandError.new(
          error: "일일 브로드캐스트 한도를 초과했습니다. (최대 #{daily_limit}개)",
          status: :too_many_requests
        )
      end
      
      # 지갑 잔액 확인
      unless @user.wallet.balance >= broadcast_cost
        raise CommandError.new(
          error: "포인트가 부족합니다.",
          balance_needed: broadcast_cost,
          current_balance: @user.wallet.balance,
          status: :payment_required
        )
      end
    end

    def create_broadcast!
      ActiveRecord::Base.transaction do
        # 브로드캐스트 생성 (active: true is default for new broadcasts)
        broadcast = @broadcast_repository.create!(
          user: @user,
          content: @content,
          active: true
        )
        
        # 음성 파일 첨부
        broadcast.audio.attach(@audio_file)
        
        # 포인트 차감
        @user.wallet.withdraw(broadcast_cost, description: "브로드캐스트 전송")
        
        Rails.logger.info("브로드캐스트 생성 성공: ID #{broadcast.id}")
        
        broadcast
      end
    end

    def select_recipients
      @recipient_selector.select(
        sender: @user,
        count: @recipient_count,
        exclude_blocked: true
      )
    end

    def serialize_broadcast(broadcast)
      {
        id: broadcast.id,
        content: broadcast.content,
        audio_url: safe_audio_url(broadcast),
        created_at: broadcast.created_at,
        sender: {
          id: @user.id,
          nickname: @user.nickname
        }
      }
    end

    def safe_audio_url(broadcast)
      return nil unless broadcast.audio.attached?

      Rails.application.routes.url_helpers.rails_blob_path(
        broadcast.audio,
        only_path: true
      )
    rescue StandardError => e
      Rails.logger.warn("Failed to generate audio URL: #{e.message}")
      nil
    end

    def normalize_recipient_count(count)
      count = count.to_i
      count = 5 if count <= 0
      count = 10 if count > 10
      count
    end

    def daily_limit
      @user.premium? ? 20 : 10
    end

    def broadcast_cost
      100 # 포인트
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