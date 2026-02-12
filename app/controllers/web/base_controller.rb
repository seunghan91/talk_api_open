# app/controllers/web/base_controller.rb
# Inertia.js 웹 페이지를 위한 기본 컨트롤러
# ActionController::Base를 상속하여 세션, CSRF, 쿠키 등 풀스택 기능 사용
module Web
  class BaseController < ActionController::Base
    layout "application"
    protect_from_forgery with: :exception

    private

    # 현재 로그인한 사용자 (세션 기반)
    def current_user
      @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
    end
    helper_method :current_user

    # 인증 필요 시 로그인 페이지로 리다이렉트
    def authenticate_user!
      unless current_user
        redirect_to "/auth/login", inertia: { location: "/auth/login" }
      end
    end

    # 사용자 활성 상태 확인
    def ensure_user_active!
      return unless current_user
      unless current_user.status_active?
        session.delete(:user_id)
        redirect_to "/auth/login"
      end
    end

    # 사용자 직렬화
    def serialize_user(user)
      {
        id: user.id,
        nickname: user.nickname,
        gender: user.gender,
        age_range: user.respond_to?(:age_range) ? user.age_range : nil,
        created_at: user.created_at.iso8601
      }
    end

    # 페이지네이션 메타 정보
    def pagination_meta(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        per_page: collection.limit_value
      }
    end
  end
end
