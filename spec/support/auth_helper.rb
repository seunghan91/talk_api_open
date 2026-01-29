module AuthHelper
  # JWT 토큰 생성 헬퍼 메서드
  # AuthToken 클래스를 직접 사용하여 일관성 유지
  def generate_token_for(user)
    AuthToken.encode({ user_id: user.id })
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
