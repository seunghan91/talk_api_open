# app/services/auth/phone_verification_service.rb
module Auth
  class PhoneVerificationService
    VERIFICATION_CODE_LENGTH = 6
    VERIFICATION_EXPIRY_MINUTES = 10
    RESEND_WAIT_SECONDS = 60

    def initialize(strategy: nil)
      @strategy = strategy || determine_strategy
    end

    def send_verification_code(phone_number)
      Rails.logger.info("인증코드 발송 시작: #{phone_number}")

      # 전화번호 유효성 검사
      unless valid_phone_number?(phone_number)
        return { success: false, error: "유효하지 않은 전화번호 형식입니다." }
      end

      # 재전송 제한 확인
      if recently_sent?(phone_number)
        wait_seconds = time_until_next_send(phone_number)
        return {
          success: false,
          error: "잠시 후 다시 시도해주세요.",
          wait_seconds: wait_seconds
        }
      end

      # 인증 코드 생성
      code = generate_verification_code

      # 인증 레코드 생성 또는 업데이트
      verification = PhoneVerification.find_or_initialize_by(phone_number: phone_number)
      verification.assign_attributes(
        code: code,
        expires_at: VERIFICATION_EXPIRY_MINUTES.minutes.from_now,
        verified: false,
        attempt_count: 0
      )
      verification.save!

      # 전략에 따라 코드 전송
      @strategy.send_code(phone_number, code)

      # 사용자 존재 여부 확인
      user_exists = User.exists?(phone_number: phone_number)

      Rails.logger.info("🔑 인증코드 발급 완료: 전화번호=#{phone_number}, 만료=#{verification.expires_at.strftime('%H:%M:%S')}")

      {
        success: true,
        message: "인증 코드가 발송되었습니다.",
        code: Rails.env.production? ? nil : code,
        expires_at: verification.expires_at,
        user_exists: user_exists
      }
    rescue => e
      Rails.logger.error("인증코드 발송 실패: #{e.message}")
      { success: false, error: "인증 코드 발송에 실패했습니다." }
    end

    def verify_code(phone_number, code)
      Rails.logger.info("인증코드 확인: #{phone_number}")

      verification = PhoneVerification.find_by(phone_number: phone_number)

      # 베타 테스트 모드 처리
      if beta_test_mode?(phone_number, code)
        return handle_beta_test_verification(phone_number)
      end

      # 인증 레코드 확인
      unless verification
        return {
          success: false,
          error: "인증 요청을 찾을 수 없습니다.",
          verification_required: true,
          verification_status: {
            verified: false,
            can_resend: true,
            message: "인증 코드를 다시 요청해주세요."
          }
        }
      end

      # 만료 확인
      if verification.expired?
        return {
          success: false,
          error: "인증 시간이 초과되었습니다. 인증을 다시 진행해주세요.",
          verification_required: true,
          verification_status: {
            verified: false,
            can_resend: true,
            expired: true,
            message: "인증이 만료되었습니다."
          }
        }
      end

      # 코드 확인
      if verification.code != code
        verification.increment!(:attempt_count)
        return {
          success: false,
          error: "인증 코드가 일치하지 않습니다.",
          verification_required: true,
          verification_status: {
            verified: false,
            can_resend: false,
            attempts_left: 5 - verification.attempt_count
          }
        }
      end

      # 인증 성공
      verification.mark_as_verified!
      user = User.find_by(phone_number: phone_number)

      {
        success: true,
        message: "인증에 성공했습니다.",
        user_exists: user.present?,
        user: user&.slice(:id, :nickname),
        verification_status: {
          verified: true,
          verified_at: verification.updated_at,
          phone_number: phone_number
        }
      }
    end

    def resend_verification_code(phone_number)
      Rails.logger.info("인증코드 재전송 요청: #{phone_number}")

      verification = PhoneVerification.find_by(phone_number: phone_number)

      unless verification
        return send_verification_code(phone_number)
      end

      # 재전송 제한 확인
      if recently_sent?(phone_number)
        wait_seconds = time_until_next_send(phone_number)
        return {
          success: false,
          error: "잠시 후 다시 시도해주세요.",
          wait_seconds: wait_seconds,
          status: :too_many_requests
        }
      end

      # 새 코드 생성 및 전송
      send_verification_code(phone_number)
    end

    private

    def determine_strategy
      if Rails.env.production?
        SmsVerificationStrategy.new
      else
        DevelopmentVerificationStrategy.new
      end
    end

    def valid_phone_number?(phone_number)
      phone_number.match?(/\A01\d{8,9}\z/)
    end

    def generate_verification_code
      if Rails.env.test?
        "123456"
      else
        rand(100000..999999).to_s
      end
    end

    def recently_sent?(phone_number)
      verification = PhoneVerification.find_by(phone_number: phone_number)
      return false unless verification

      verification.created_at > RESEND_WAIT_SECONDS.seconds.ago ||
        verification.updated_at > RESEND_WAIT_SECONDS.seconds.ago
    end

    def time_until_next_send(phone_number)
      verification = PhoneVerification.find_by(phone_number: phone_number)
      return 0 unless verification

      last_sent = [verification.created_at, verification.updated_at].max
      wait_until = last_sent + RESEND_WAIT_SECONDS.seconds
      [wait_until - Time.current, 0].max.to_i
    end

    def beta_test_mode?(phone_number, code)
      !Rails.env.production? && code == "111111"
    end

    def handle_beta_test_verification(phone_number)
      Rails.logger.info("베타 테스트 모드 - 자동 인증: #{phone_number}")

      verification = PhoneVerification.find_or_create_by(phone_number: phone_number) do |v|
        v.code = "111111"
        v.expires_at = 1.hour.from_now
        v.verified = true
        v.attempt_count = 0
      end

      verification.mark_as_verified! unless verification.verified

      user = User.find_by(phone_number: phone_number)

      {
        success: true,
        message: "인증에 성공했습니다. (베타 테스트)",
        user_exists: user.present?,
        user: user&.slice(:id, :nickname),
        verification_status: {
          verified: true,
          verified_at: verification.updated_at,
          phone_number: phone_number
        }
      }
    end
  end

  # Strategy Pattern 구현
  class VerificationStrategy
    def send_code(phone_number, code)
      raise NotImplementedError
    end
  end

  class SmsVerificationStrategy < VerificationStrategy
    def send_code(phone_number, code)
      # 실제 SMS 전송 로직
      # TwilioClient.send_sms(phone_number, "인증 코드: #{code}")
      Rails.logger.info("SMS 전송: #{phone_number}, 코드: [HIDDEN]")
    end
  end

  class DevelopmentVerificationStrategy < VerificationStrategy
    def send_code(phone_number, code)
      Rails.logger.info("개발 환경: 인증 코드 = #{code}")
    end
  end

  class EmailVerificationStrategy < VerificationStrategy
    def send_code(phone_number, code)
      # 이메일 전송 로직 (향후 확장 가능)
      Rails.logger.info("Email 전송: #{phone_number}, 코드: #{code}")
    end
  end
end 