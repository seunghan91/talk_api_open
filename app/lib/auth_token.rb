class AuthToken
  SECRET_KEY = Rails.application.secrets.secret_key_base.to_s
  DEFAULT_EXPIRY = 7.days.to_i

  def self.encode(payload, exp = DEFAULT_EXPIRY)
    payload = {
      data: payload,
      exp: Time.now.to_i + exp
    }
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    begin
      decoded = JWT.decode(token, SECRET_KEY)[0]
      HashWithIndifferentAccess.new(decoded)["data"]
    rescue JWT::ExpiredSignature
      # 토큰 만료 시
      Rails.logger.warn("만료된 JWT 토큰: #{token[0..15]}...")
      raise JWT::ExpiredSignature
    rescue JWT::DecodeError => e
      # 토큰 디코딩 오류 시
      Rails.logger.error("JWT 디코딩 오류: #{e.message}, 토큰: #{token[0..15]}...")
      raise JWT::DecodeError.new("유효하지 않은 토큰입니다: #{e.message}")
    end
  end
end
