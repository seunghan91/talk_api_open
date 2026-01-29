# app/lib/auth_token.rb
class AuthToken
  SECRET_KEY = Rails.application.credentials.secret_key_base || ENV['SECRET_KEY_BASE'] || Rails.application.secret_key_base
  ALGORITHM = 'HS256'
  DEFAULT_EXPIRY = 24.hours
  
  class << self
    def encode(payload, expiry = DEFAULT_EXPIRY)
      payload = payload.dup
      payload[:exp] = (Time.current + expiry).to_i
      payload[:iat] = Time.current.to_i
      
      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end
    
    def decode(token)
      decoded = JWT.decode(token, SECRET_KEY, true, algorithm: ALGORITHM).first
      HashWithIndifferentAccess.new(decoded)
    rescue JWT::DecodeError => e
      Rails.logger.warn("JWT decode error: #{e.message}")
      nil
    rescue JWT::ExpiredSignature
      Rails.logger.warn("JWT token expired")
      nil
    rescue JWT::InvalidIatError
      Rails.logger.warn("JWT invalid iat")
      nil
    end
    
    def valid?(token)
      decode(token).present?
    end
    
    def refresh(token)
      payload = decode(token)
      return nil unless payload
      
      # 기존 payload에서 exp와 iat 제거
      new_payload = payload.except(:exp, :iat)
      
      # 새로운 토큰 생성
      encode(new_payload)
    end
  end
end
