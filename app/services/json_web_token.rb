# app/services/json_web_token.rb
require "jwt"

class JsonWebToken
  SECRET_KEY = Rails.application.credentials.dig(:jwt_secret) || ENV["JWT_SECRET"]
  ALGORITHM = "HS256"

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY, ALGORITHM)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY, true, algorithm: ALGORITHM)[0]
    HashWithIndifferentAccess.new(decoded)
  rescue JWT::ExpiredSignature
    raise ApiError::TokenExpired
  rescue JWT::DecodeError
    raise ApiError::InvalidToken
  end
end
