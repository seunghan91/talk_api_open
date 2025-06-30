module Broadcasts
  class CreateService
    # Result 객체 패턴으로 성공/실패 처리
    class Result
      attr_reader :success, :broadcast, :error

      def initialize(success:, broadcast: nil, error: nil)
        @success = success
        @broadcast = broadcast
        @error = error
      end

      def success?
        @success
      end
    end

    def initialize(user:, audio:, text:, recipient_count:, worker: BroadcastWorker)
      @user = user
      @audio = audio
      @text = text
      @recipient_count = normalize_recipient_count(recipient_count)
      @worker = worker # 의존성 주입
    end

    def call
      # 유효성 검사
      validation_result = validate_inputs
      return validation_result unless validation_result.success?

      # 트랜잭션으로 브로드캐스트 생성
      ActiveRecord::Base.transaction do
        broadcast = create_broadcast
        enqueue_background_job(broadcast)

        Result.new(success: true, broadcast: broadcast)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, error: e.message)
    rescue => e
      Rails.logger.error("브로드캐스트 생성 중 오류: #{e.message}")
      Result.new(success: false, error: "브로드캐스트 생성 중 오류가 발생했습니다.")
    end

    private

    def validate_inputs
      return Result.new(success: false, error: "음성 파일이 필요합니다.") unless @audio.present?
      return Result.new(success: false, error: "텍스트가 너무 깁니다. (최대 200자)") if @text && @text.length > 200

      Result.new(success: true)
    end

    def create_broadcast
      @user.broadcasts.create!(
        text: @text,
        audio: @audio,
        content: @text # 기존 모델과의 호환성
      )
    end

    def enqueue_background_job(broadcast)
      @worker.perform_async(broadcast.id, @recipient_count)
    end

    def normalize_recipient_count(count)
      count = count.to_i
      return 5 if count <= 0  # 기본값
      return 10 if count > 10 # 최대값
      count
    end
  end
end
