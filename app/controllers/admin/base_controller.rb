module Admin
  class BaseController < ActionController::Base
    layout "application"
    before_action :authenticate_admin!
    protect_from_forgery with: :exception

    private

    def authenticate_admin!
      if Rails.env.development? || Rails.env.test?
        admin = OpenStruct.new(email: "admin@example.com", id: 1)
        define_singleton_method(:current_admin) { admin }
      else
        redirect_to root_path, alert: "권한이 없습니다." unless current_user&.admin?
      end
    end
  end
end
