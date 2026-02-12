# app/controllers/web/auth_controller.rb
# 웹 인증 플로우 (세션 기반)
module Web
  class AuthController < Web::BaseController
    before_action :redirect_if_authenticated, only: [:login, :verify, :register]

    # GET /auth/login
    def login
      render inertia: "Auth/Login"
    end

    # POST /auth/login
    def create_session
      phone_number = normalize_phone(params[:phone_number])
      service = ::Auth::PhoneVerificationService.new
      result = service.send_verification_code(phone_number)

      if result[:success]
        session[:pending_phone] = phone_number
        redirect_to "/auth/verify", notice: result[:message]
      else
        redirect_to "/auth/login", inertia: { errors: { phone_number: result[:error] } }
      end
    end

    # GET /auth/verify
    def verify
      unless session[:pending_phone]
        redirect_to "/auth/login"
        return
      end

      render inertia: "Auth/Verify", props: {
        phone_number: mask_phone(session[:pending_phone])
      }
    end

    # POST /auth/verify
    def verify_code
      phone_number = session[:pending_phone]
      unless phone_number
        redirect_to "/auth/login"
        return
      end

      service = ::Auth::PhoneVerificationService.new
      result = service.verify_code(phone_number, params[:code])

      if result[:success]
        if result[:user_exists]
          # 기존 사용자 -> 로그인
          user = User.find_by(phone_number: phone_number)
          session[:user_id] = user.id
          session.delete(:pending_phone)
          redirect_to "/"
        else
          # 신규 사용자 -> 회원가입
          session[:verified_phone] = phone_number
          session.delete(:pending_phone)
          redirect_to "/auth/register"
        end
      else
        redirect_to "/auth/verify", inertia: { errors: { code: result[:error] } }
      end
    end

    # GET /auth/register
    def register
      unless session[:verified_phone]
        redirect_to "/auth/login"
        return
      end

      render inertia: "Auth/Register"
    end

    # POST /auth/register
    def create_user
      phone_number = session[:verified_phone]
      unless phone_number
        redirect_to "/auth/login"
        return
      end

      user = User.new(
        phone_number: phone_number,
        nickname: params[:nickname],
        password: params[:password],
        password_confirmation: params[:password_confirmation],
        gender: params[:gender] || :unknown
      )

      if user.save
        # 지갑 생성
        Wallet.create(user: user) if defined?(Wallet)

        session[:user_id] = user.id
        session.delete(:verified_phone)
        redirect_to "/", notice: "회원가입이 완료되었습니다!"
      else
        redirect_to "/auth/register", inertia: {
          errors: user.errors.messages.transform_values(&:first)
        }
      end
    end

    # DELETE /auth/logout
    def destroy
      session.delete(:user_id)
      session.delete(:pending_phone)
      session.delete(:verified_phone)
      redirect_to "/auth/login", notice: "로그아웃되었습니다."
    end

    # POST /auth/resend
    def resend_code
      phone_number = session[:pending_phone]
      unless phone_number
        redirect_to "/auth/login"
        return
      end

      service = ::Auth::PhoneVerificationService.new
      result = service.resend_verification_code(phone_number)

      redirect_to "/auth/verify", notice: result[:success] ? "인증 코드가 재전송되었습니다." : result[:error]
    end

    private

    def redirect_if_authenticated
      redirect_to "/" if current_user
    end

    def normalize_phone(phone)
      phone.to_s.gsub(/[\s\-]/, "")
    end

    def mask_phone(phone)
      return "" unless phone
      "#{phone[0..2]}****#{phone[-4..]}"
    end
  end
end
