# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include ApiAuthentication

  before_action :authorize_request

  def render_unauthorized
    render json: { error: "인증이 필요합니다. 로그인 후 이용해주세요." }, status: :unauthorized
  end
end
