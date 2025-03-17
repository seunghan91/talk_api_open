# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :authorize_request

  attr_reader :current_user

  private

  def authorize_request
    header = request.headers['Authorization']
    if header.present?
      token = header.split(' ').last
      decoded = JsonWebToken.decode(token)  # => { user_id: 1, exp: 1234567890, ... } or nil
      if decoded && decoded[:user_id]
        @current_user = User.find_by(id: decoded[:user_id])
      end
    end

    # 인증 실패 시
    unless @current_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end