module AuthHelper
  # JWT 토큰 생성 헬퍼 메서드
  def generate_token_for(user)
    payload = {
      user_id: user.id,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end

  # 인증 헤더 생성
  def auth_headers_for(user)
    token = generate_token_for(user)
    { 'Authorization' => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
