module Api
  module V1
    class SettingsController < ApplicationController
      before_action :authorize_request

      # 설정 업데이트
      def update
        begin
          # 유저의 알림 설정 가져오기
          setting_params = params.require(:setting).permit(:push_enabled, :marketing_push_enabled, :sound_enabled)

          # 로깅 추가
          Rails.logger.info("설정 업데이트 요청: 사용자 ID #{current_user.id}, 설정: #{setting_params.inspect}")

          # 현재 설정값 로깅
          Rails.logger.info("현재 설정값: #{current_user.setting&.attributes}")

          # 설정 업데이트 또는 생성
          setting = current_user.setting || current_user.build_setting

          # 설정값 업데이트
          if setting.update(setting_params)
            # 성공적으로 업데이트된 후 다시 확인
            setting.reload
            Rails.logger.info("설정 업데이트 성공: #{setting.attributes}")

            render json: {
              setting: {
                push_enabled: setting.push_enabled,
                marketing_push_enabled: setting.marketing_push_enabled,
                sound_enabled: setting.sound_enabled
              },
              request_id: request.request_id || SecureRandom.uuid
            }, status: :ok
          else
            Rails.logger.error("설정 업데이트 실패: #{setting.errors.full_messages.join(', ')}")
            render json: {
              error: "설정을 업데이트하는 데 실패했습니다.",
              details: setting.errors.full_messages,
              request_id: request.request_id || SecureRandom.uuid
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("설정 업데이트 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: {
            error: "설정을 업데이트하는 데 실패했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      # 설정 조회
      def show
        begin
          setting = current_user.setting

          # 설정이 없으면 기본값으로 생성
          unless setting
            setting = current_user.create_setting(
              push_enabled: true,
              marketing_push_enabled: true,
              sound_enabled: true
            )
          end

          render json: {
            setting: {
              push_enabled: setting.push_enabled,
              marketing_push_enabled: setting.marketing_push_enabled,
              sound_enabled: setting.sound_enabled
            },
            request_id: request.request_id || SecureRandom.uuid
          }, status: :ok
        rescue => e
          Rails.logger.error("설정 조회 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: {
            error: "설정을 조회하는 데 실패했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end
    end
  end
end
