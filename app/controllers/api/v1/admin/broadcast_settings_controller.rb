# frozen_string_literal: true

module Api
  module V1
    module Admin
      class BroadcastSettingsController < Api::V1::BaseController
        before_action :authorize_request
        before_action :authorize_admin!

        # GET /api/v1/admin/broadcast_settings
        def show
          settings = SystemSetting.broadcast_limits

          render json: {
            daily_limit: settings["daily_limit"],
            hourly_limit: settings["hourly_limit"],
            cooldown_minutes: settings["cooldown_minutes"],
            bypass_roles: settings["bypass_roles"],
            request_id: request.request_id || SecureRandom.uuid
          }
        end

        # PATCH /api/v1/admin/broadcast_settings
        def update
          setting = SystemSetting.update_broadcast_limits!(
            broadcast_settings_params,
            updated_by: current_user
          )

          render json: {
            message: "브로드캐스트 제한 설정이 업데이트되었습니다.",
            settings: {
              daily_limit: setting.setting_value["daily_limit"],
              hourly_limit: setting.setting_value["hourly_limit"],
              cooldown_minutes: setting.setting_value["cooldown_minutes"],
              bypass_roles: setting.setting_value["bypass_roles"]
            },
            updated_by: current_user.nickname,
            updated_at: setting.updated_at,
            request_id: request.request_id || SecureRandom.uuid
          }
        rescue ArgumentError => e
          render json: {
            error: e.message,
            request_id: request.request_id || SecureRandom.uuid
          }, status: :unprocessable_entity
        rescue => e
          Rails.logger.error("브로드캐스트 설정 업데이트 오류: #{e.message}")
          render json: {
            error: "설정을 업데이트하는 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end

        private

        def authorize_admin!
          unless current_user.admin?
            render json: {
              error: "관리자 권한이 필요합니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :forbidden
          end
        end

        def broadcast_settings_params
          permitted = params.permit(:daily_limit, :hourly_limit, :cooldown_minutes, bypass_roles: [])
          result = {}
          result["daily_limit"] = permitted[:daily_limit].to_i if permitted[:daily_limit].present?
          result["hourly_limit"] = permitted[:hourly_limit].to_i if permitted[:hourly_limit].present?
          result["cooldown_minutes"] = permitted[:cooldown_minutes].to_i if permitted[:cooldown_minutes].present?
          result["bypass_roles"] = permitted[:bypass_roles] if permitted[:bypass_roles].present?
          result
        end
      end
    end
  end
end
