# app/controllers/pages_controller.rb
class PagesController < ActionController::Base
  # 그냥 skip_before_action :authorize_request 제거

  def home
    # HTML 렌더링
    render json: { message: "Hello, World!" }
  end
end
