# app/controllers/api_controller.rb
class ApiController < ActionController::Base
  protect_from_forgery with: :null_session

  before_action :authorize_request

  private

  def authorize_request
    header = request.headers["Authorization"]
    header = header.split(" ").last if header

    begin
      @decoded = JsonWebToken.decode(header)
      @current_user = User.find(@decoded[:user_id])
    rescue ActiveRecord::RecordNotFound => e
      render json: { errors: e.message }, status: :unauthorized
    rescue JWT::DecodeError => e
      render json: { errors: "Invalid token" }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end
end
