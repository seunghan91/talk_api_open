# production/staging에서는 반드시 SECRET_KEY_BASE를 설정해야 합니다.
if Rails.env.production? || Rails.env.staging?
  secret = ENV["SECRET_KEY_BASE"].presence
  if secret.blank?
    raise "SECRET_KEY_BASE is required in #{Rails.env} environment"
  end

  Rails.application.config.secret_key_base = secret
end
