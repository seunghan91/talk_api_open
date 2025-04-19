module Admin
  class BaseController < ActionController::Base
    layout "admin"
    before_action :authenticate_admin! # 필요 시
    protect_from_forgery with: :exception
  end
end
