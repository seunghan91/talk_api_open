# app/controllers/health_check_controller.rb
class HealthCheckController < ActionController::API
  def index
    render json: { status: "OK", timestamp: Time.current, environment: Rails.env }, status: :ok
  end
end
