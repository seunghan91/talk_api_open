module ApiAuthentication
  extend ActiveSupport::Concern

  def current_user
    @current_user
  end

  private

  def authorize_request
    @current_session = find_session_by_token
    if @current_session
      @current_session.touch_last_active!
      @current_user = @current_session.user
    else
      render json: { error: "인증이 필요합니다." }, status: :unauthorized
    end
  end

  def find_session_by_token
    token = extract_token_from_header
    return nil unless token
    Session.includes(:user).active.find_by(token: token)
  end

  def extract_token_from_header
    request.headers["Authorization"]&.split(" ")&.last
  end

  def start_new_session_for(user)
    user.sessions.create!(
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      last_active_at: Time.current
    )
  end

  def terminate_session
    @current_session&.destroy
  end
end
