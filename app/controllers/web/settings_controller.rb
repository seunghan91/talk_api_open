# app/controllers/web/settings_controller.rb
module Web
  class SettingsController < Web::BaseController
    before_action :authenticate_user!

    # GET /settings
    def show
      render inertia: "Settings/Index", props: {
        settings: {
          notification_settings: {
            push_enabled: current_user.push_enabled,
            broadcast_push_enabled: current_user.broadcast_push_enabled,
            message_push_enabled: current_user.message_push_enabled
          },
          blocked_users_count: current_user.respond_to?(:blocks) ? current_user.blocks.count : 0
        }
      }
    end

    # PATCH /settings
    def update
      if current_user.update(user_settings_params)
        redirect_to "/settings", notice: "설정이 저장되었습니다."
      else
        redirect_to "/settings", alert: "설정 저장에 실패했습니다."
      end
    end

    private

    def user_settings_params
      params.permit(:push_enabled, :broadcast_push_enabled, :message_push_enabled)
    end
  end
end
