# app/controllers/auth_controller.rb

class AuthController < ApplicationController
  include ApiAuthentication

  # 인증, 로그인, 회원가입은 토큰 없이 접근해야 하므로:
  skip_before_action :authorize_request, only: [ :request_code, :verify_code, :login, :register ]

  # 1) 인증코드 발송
  def request_code
    phone_number = params[:phone_number]
    return render json: { error: "전화번호가 필요합니다." }, status: :bad_request if phone_number.blank?

    # 6자리 난수
    code = rand(100000..999999).to_s

    verification = PhoneVerification.create!(
      phone_number: phone_number,
      code: code,
      expires_at: 5.minutes.from_now,
      verified: false
    )

    # 실제로는 Twilio/알리고/카카오 인증 API를 호출해서 'code' 전송
    # TwilioClient.send_sms(phone_number, "인증코드: #{code}")

    render json: {
      phone_number: phone_number,
      code: code,
      message: "인증코드 발송(테스트용)",
      verification_id: verification.id
    }, status: :ok
  end

  # 2) 인증코드 검증 & 세션 토큰 발급
  def verify_code
    # `user` 네임스페이스를 지원하기 위해 파라미터 처리 개선
    user_params = params[:user] || {}
    phone_number = user_params[:phone_number] || params[:phone_number]
    input_code = user_params[:code] || params[:code]

    # 오류 메시지 개선
    if phone_number.blank?
      return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
    end

    if input_code.blank?
      return render json: { error: "인증코드를 입력해 주세요." }, status: :bad_request
    end

    # 개발 환경에서 테스트를 위한 처리: 111111 코드는 항상 성공
    if Rails.env.development? && input_code == "111111"
      Rails.logger.info "===> 테스트 모드: 고정 코드(111111) 사용하여 인증 성공"
      verification = PhoneVerification.create!(
        phone_number: phone_number,
        code: input_code,
        expires_at: 30.minutes.from_now,
        verified: true
      )
    else
      # 일반적인 경우: phone_number + verified=false + 만료 안된 verification을 찾는다
      verification = PhoneVerification.where(phone_number: phone_number, verified: false)
                                    .where("expires_at > ?", Time.current)
                                    .order(created_at: :desc)
                                    .first

      unless verification
        return render json: { error: "유효한 인증요청이 없거나 이미 만료" }, status: :unauthorized
      end
    end

    # 테스트 코드가 아닌 일반적인 경우에 코드 비교
    if Rails.env.development? && input_code == "111111" || verification.code == input_code
      # 인증 성공
      verification.update(verified: true)

      # 유저 찾거나 생성
      Rails.logger.debug "===> phone_number: #{phone_number}"
      user = User.find_or_create_by(phone_number: phone_number) do |u|
        u.gender   = :unknown
        u.verified = true
        # 새 사용자일 경우 랜덤 한글 닉네임 자동 생성
        u.nickname = NicknameGenerator.generate_unique
      end

      # 기존 사용자인데 닉네임이 없는 경우에도 닉네임 생성
      if user.nickname.blank?
        user.update(nickname: NicknameGenerator.generate_unique)
      end

      # PhoneVerification과 User 연결
      verification.update(user: user)

      # user가 nil이 아닌지 확인 (디버깅)
      Rails.logger.debug "===> created user: #{user.inspect}"

      # 세션 토큰 발급
      session = start_new_session_for(user)

      render json: {
        message: "인증 완료",
        token: session.token,
        user: {
          id: user.id,
          phone_number: user.phone_number,
          nickname: user.nickname,  # 닉네임 추가
          verified: user.verified,
          gender: user.gender
        }
      }, status: :ok
    else
      render json: { error: "인증코드가 올바르지 않습니다." }, status: :unauthorized
    end
  end

  # 전화번호/비밀번호로 로그인
  def login
    # `user` 네임스페이스를 지원하기 위해 파라미터 처리 개선
    user_params = params[:user] || {}
    phone_number = user_params[:phone_number] || params[:phone_number]
    password = user_params[:password] || params[:password]

    # 오류 메시지 개선
    if phone_number.blank?
      return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
    end

    if password.blank?
      return render json: { error: "비밀번호를 입력해 주세요." }, status: :bad_request
    end

    # 사용자 찾기
    user = User.find_by(phone_number: phone_number)

    # 사용자 인증
    if user && user.authenticate(password)
      # 세션 토큰 발급
      session = start_new_session_for(user)

      render json: {
        message: "로그인 성공",
        token: session.token,
        user: {
          id: user.id,
          phone_number: user.phone_number,
          nickname: user.nickname,
          verified: user.verified,
          gender: user.gender
        }
      }, status: :ok
    else
      # 인증 실패
      render json: { error: "전화번호 또는 비밀번호가 올바르지 않습니다." }, status: :unauthorized
    end
  end

  # 회원가입 처리
  def register
    # `user` 네임스페이스를 지원하기 위해 파라미터 처리 개선
    user_params = params[:user] || {}
    phone_number = user_params[:phone_number] || params[:phone_number]
    password = user_params[:password] || params[:password]
    password_confirmation = user_params[:password_confirmation] || params[:password_confirmation] || password
    nickname = user_params[:nickname] || params[:nickname]
    gender = user_params[:gender] || params[:gender]

    # 오류 메시지 개선
    if phone_number.blank?
      return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
    end

    if password.blank?
      return render json: { error: "비밀번호를 입력해 주세요." }, status: :bad_request
    end

    # 비밀번호 일치 확인
    if password != password_confirmation
      return render json: { error: "비밀번호와 비밀번호 확인이 일치하지 않습니다." }, status: :bad_request
    end

    # 이미 존재하는 전화번호인지 확인
    if User.exists?(phone_number: phone_number)
      return render json: { error: "이미 등록된 전화번호입니다.", user_exists: true }, status: :unprocessable_entity
    end

    # 닉네임이 없으면 생성
    nickname = NicknameGenerator.generate_unique if nickname.blank?

    # 사용자 생성
    user = User.new(
      phone_number: phone_number,
      password: password,
      password_confirmation: password_confirmation,
      nickname: nickname,
      gender: gender || "unspecified",
      verified: true # 회원가입 시 자동 인증
    )

    if user.save
      # 세션 토큰 발급
      session = start_new_session_for(user)

      render json: {
        message: "회원가입 성공",
        token: session.token,
        user: {
          id: user.id,
          phone_number: user.phone_number,
          nickname: user.nickname,
          verified: user.verified,
          gender: user.gender
        }
      }, status: :created
    else
      # 저장 실패 시 오류 메시지 반환
      render json: { error: user.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end
end
