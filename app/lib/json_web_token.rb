# app/lib/json_web_token.rb 또는 app/services/json_web_token.rb
module JsonWebToken
  # 환경 변수에서 SECRET_KEY_BASE를 가져오거나, 없으면 credentials에서 가져옴
  SECRET_KEY = ENV["SECRET_KEY_BASE"].presence || Rails.application.credentials.secret_key_base.to_s

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i

    # SECRET_KEY가 비어있는지 확인하고 로그 추가
    if SECRET_KEY.blank?
      Rails.logger.error("SECRET_KEY가 설정되지 않았습니다. 환경 변수 SECRET_KEY_BASE를 확인하세요.")
      raise "시크릿 키가 설정되지 않았습니다. 환경 변수 SECRET_KEY_BASE를 확인하세요."
    end

    JWT.encode(payload, SECRET_KEY, "HS256")
  end

  def self.decode(token)
    # SECRET_KEY가 비어있는지 확인하고 로그 추가
    if SECRET_KEY.blank?
      Rails.logger.error("SECRET_KEY가 설정되지 않았습니다. 환경 변수 SECRET_KEY_BASE를 확인하세요.")
      raise "시크릿 키가 설정되지 않았습니다. 환경 변수 SECRET_KEY_BASE를 확인하세요."
    end

    body = JWT.decode(token, SECRET_KEY, true, { algorithm: "HS256" })[0]
    HashWithIndifferentAccess.new(body)
  rescue JWT::ExpiredSignature => e
    Rails.logger.warn("토큰이 만료되었습니다: #{e.message}")
    raise JWT::ExpiredSignature
  rescue JWT::DecodeError => e
    Rails.logger.warn("토큰 디코딩 오류: #{e.message}")
    raise JWT::DecodeError
  end
end
