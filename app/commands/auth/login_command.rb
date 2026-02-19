# app/commands/auth/login_command.rb
module Auth
  class LoginCommand
    def initialize(phone_number:, password:, user_repository: nil)
      @phone_number = phone_number
      @password = password
      
      # 의존성 주입 (DIP)
      @user_repository = user_repository || UserRepository.new
    end

    def execute
      validate_params!
      
      user = authenticate_user!
      update_login_info(user)
      
      {
        success: true,
        user: user,
        user_data: serialize_user(user)
      }
    rescue CommandError => e
      e.to_h.merge(success: false)
    rescue => e
      Rails.logger.error("로그인 실패: #{e.message}")
      { success: false, error: "로그인 중 오류가 발생했습니다.", status: :internal_server_error }
    end

    private

    def validate_params!
      errors = []
      
      errors << "전화번호를 입력해 주세요." if @phone_number.blank?
      errors << "비밀번호를 입력해 주세요." if @password.blank?
      
      if errors.any?
        raise CommandError.new(
          error: errors.first,
          status: :bad_request
        )
      end
    end

    def authenticate_user!
      Rails.logger.info("로그인 시도: #{@phone_number}")
      
      # 사용자 찾기
      user = @user_repository.find_by_phone(@phone_number)
      
      # 사용자가 없거나 비밀번호가 일치하지 않으면
      unless user && user.authenticate(@password)
        Rails.logger.warn("로그인 실패: #{@phone_number} - 사용자가 없거나 비밀번호가 일치하지 않음")
        raise CommandError.new(
          error: "전화번호 또는 비밀번호가 올바르지 않습니다.",
          status: :unauthorized
        )
      end
      
      # 계정 상태 확인
      check_account_status!(user)
      
      user
    end

    def check_account_status!(user)
      case user.status
      when "suspended"
        suspension = user.user_suspensions.active.first
        raise CommandError.new(
          error: "계정이 일시 정지되었습니다.",
          suspended_until: suspension&.suspended_until,
          reason: suspension&.reason,
          status: :forbidden
        )
      when "banned"
        raise CommandError.new(
          error: "계정이 영구 정지되었습니다.",
          status: :forbidden
        )
      end
    end

    def update_login_info(user)
      user.update(last_login_at: Time.current)
      Rails.logger.info("로그인 성공: 사용자 ID #{user.id}")
    end

    def serialize_user(user)
      {
        id: user.id,
        nickname: user.nickname,
        phone_number: user.phone_number,
        last_login_at: user.last_login_at,
        created_at: user.created_at
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