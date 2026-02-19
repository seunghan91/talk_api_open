# app/commands/auth/register_user_command.rb
module Auth
  class RegisterUserCommand
    def initialize(phone_number:, password:, password_confirmation:, nickname:, gender: nil,
                   user_repository: nil, notification_service: nil, wallet_service: nil)
      @phone_number = phone_number
      @password = password
      @password_confirmation = password_confirmation
      @nickname = nickname
      @gender = gender || "unspecified"
      
      # 의존성 주입 (DIP)
      @user_repository = user_repository || UserRepository.new
      @notification_service = notification_service || NotificationService.new
      @wallet_service = wallet_service || WalletService.new
    end

    def execute
      validate_params!
      check_phone_verification!
      check_existing_user!
      
      user = create_user!
      
      {
        success: true,
        user: user,
        user_data: serialize_user(user)
      }
    rescue CommandError => e
      e.to_h.merge(success: false)
    rescue => e
      Rails.logger.error("회원가입 실패: #{e.message}")
      { success: false, error: "회원가입 중 오류가 발생했습니다.", status: :internal_server_error }
    end

    private

    def validate_params!
      errors = []
      
      errors << "전화번호를 입력해 주세요." if @phone_number.blank?
      errors << "비밀번호를 입력해 주세요." if @password.blank?
      errors << "비밀번호가 일치하지 않습니다." if @password != @password_confirmation
      errors << "비밀번호는 6자 이상이어야 합니다." if @password.present? && @password.length < 6
      errors << "닉네임을 입력해 주세요." if @nickname.blank?
      
      if errors.any?
        raise CommandError.new(
          error: errors.first,
          errors: errors,
          status: :bad_request
        )
      end
    end

    def check_phone_verification!
      verification = PhoneVerification.find_by(phone_number: @phone_number)
      
      # 베타 테스트 기간 동안 인증 검증 우회 옵션
      if skip_verification?
        create_auto_verification if verification.nil?
        return
      end
      
      unless verification&.verified?
        Rails.logger.warn("회원가입 실패: #{@phone_number} - 인증되지 않은 전화번호")
        raise CommandError.new(
          error: "인증이 완료되지 않은 전화번호입니다.",
          verification_required: true,
          verification_status: {
            verified: false,
            can_resend: true,
            message: "인증 코드 확인이 필요합니다."
          },
          status: :unprocessable_entity
        )
      end
      
      # 인증 시간 확인
      if verification.updated_at < 30.minutes.ago
        Rails.logger.warn("회원가입 실패: #{@phone_number} - 인증 시간 초과")
        raise CommandError.new(
          error: "인증 시간이 초과되었습니다. 인증을 다시 진행해주세요.",
          verification_required: true,
          verification_status: {
            verified: false,
            can_resend: true,
            expired: true,
            message: "인증이 만료되었습니다."
          },
          status: :unprocessable_entity
        )
      end
    end

    def check_existing_user!
      if @user_repository.exists_by_phone?(@phone_number)
        Rails.logger.warn("회원가입 실패: #{@phone_number} - 이미 등록된 전화번호")
        raise CommandError.new(
          error: "이미 등록된 전화번호입니다.",
          user_exists: true,
          status: :unprocessable_entity
        )
      end
    end

    def create_user!
      ActiveRecord::Base.transaction do
        # 사용자 생성
        user = @user_repository.create!(
          phone_number: @phone_number,
          password: @password,
          nickname: @nickname,
          gender: @gender,
          last_login_at: Time.current
        )
        
        # 지갑 생성
        @wallet_service.create_wallet_for_user(user)
        
        # 환영 알림 발송
        @notification_service.send_welcome_notification(user)
        
        Rails.logger.info("회원가입 성공: 사용자 ID #{user.id}")
        
        user
      end
    end

    def serialize_user(user)
      {
        id: user.id,
        nickname: user.nickname,
        phone_number: user.phone_number,
        created_at: user.created_at
      }
    end

    def skip_verification?
      # 베타 테스트 환경에서만 true
      Rails.env.development? || Rails.env.test?
    end

    def create_auto_verification
      PhoneVerification.create!(
        phone_number: @phone_number,
        code: "123456",
        expires_at: 1.hour.from_now,
        verified: true,
        attempt_count: 0
      )
      Rails.logger.info("베타 테스트 - 자동 인증 생성: #{@phone_number}")
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
        { error: error, errors: errors, status: status }.merge(extra)
      end
    end
  end
end 