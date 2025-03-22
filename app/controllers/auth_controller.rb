# app/controllers/auth_controller.rb

class AuthController < ApplicationController
  # 인증코드 발행/검증은 JWT 없이 접근해야 하므로:
  skip_before_action :authorize_request, only: [:request_code, :verify_code]

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

  # 2) 인증코드 검증 & JWT 발급
  def verify_code
    phone_number = params[:phone_number]   # 변수명을 phone_number로 통일
    input_code   = params[:code]
    return render json: { error: "전화번호와 코드가 필요합니다." }, status: :bad_request if phone_number.blank? || input_code.blank?

    # phone_number + verified=false + 만료 안된 verification을 찾는다
    verification = PhoneVerification.where(phone_number: phone_number, verified: false)
                                    .where("expires_at > ?", Time.current)
                                    .order(created_at: :desc)
                                    .first

    unless verification
      return render json: { error: "유효한 인증요청이 없거나 이미 만료" }, status: :unauthorized
    end

    if verification.code == input_code
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

      # JWT 발급 (JsonWebToken 서비스 클래스)
      token = ::JsonWebToken.encode(user_id: user.id)

      render json: {
        message: "인증 완료",
        token: token,
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
end