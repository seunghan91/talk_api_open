module AuthHelper
  def auth_headers_for(user)
    session = user.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      last_active_at: Time.current
    )
    { "Authorization" => "Bearer #{session.token}" }
  end

  def auth_token_for(user)
    session = user.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      last_active_at: Time.current
    )
    session.token
  end

  # Legacy alias for specs that use generate_token_for
  alias_method :generate_token_for, :auth_token_for
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
  config.include AuthHelper, type: :integration
end
