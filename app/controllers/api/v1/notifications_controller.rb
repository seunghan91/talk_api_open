module Api
  module V1
    class NotificationsController < ApplicationController
      before_action :authorize_request
      before_action :set_notification, only: [ :show, :update, :mark_as_read ]

      # 알림 목록 조회
      def index
        notifications = current_user.notifications.recent

        # 필터링 (읽음/안읽음 상태)
        if params[:read].present?
          notifications = notifications.where(read: params[:read] == "true")
        end

        # 타입별 필터링
        if params[:type].present?
          notifications = notifications.where(notification_type: params[:type])
        end

        # 페이지네이션 (임시로 limit 사용)
        page = (params[:page] || 1).to_i
        per_page = 20
        offset = (page - 1) * per_page

        total_count = notifications.count
        notifications = notifications.limit(per_page).offset(offset)

        render json: {
          notifications: notifications.map { |n| format_notification(n) },
          unread_count: current_user.notifications.unread.count,
          pagination: {
            current_page: page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count
          }
        }
      end

      # 단일 알림 조회
      def show
        render json: format_notification(@notification)
      end

      # 알림 읽음 처리 (PATCH /api/v1/notifications/:id)
      def update
        if @notification.update(read: true)
          render json: {
            success: true,
            message: "알림이 읽음 처리되었습니다.",
            unread_count: current_user.notifications.unread.count
          }
        else
          render json: {
            error: "알림 읽음 처리에 실패했습니다."
          }, status: :unprocessable_entity
        end
      end

      # 알림 읽음 처리 (PATCH /api/v1/notifications/:id/mark_as_read - 호환성)
      def mark_as_read
        if @notification.update(read: true)
        render json: {
          success: true,
          message: "알림이 읽음 처리되었습니다.",
          unread_count: current_user.notifications.unread.count
        }
        else
          render json: {
            error: "알림 읽음 처리에 실패했습니다."
          }, status: :unprocessable_entity
        end
      end

      # 모든 알림 읽음 처리
      def mark_all_as_read
        current_user.notifications.unread.update_all(read: true)

        render json: {
          success: true,
          message: "모든 알림이 읽음 처리되었습니다.",
          unread_count: 0
        }
      end

      # 읽지 않은 알림 수 조회
      def unread_count
        render json: {
          unread_count: current_user.notifications.unread.count
        }
      end

      # 푸시 토큰 업데이트
      def update_push_token
        token = params[:push_token]

        if token.blank?
          return render json: { error: "푸시 토큰이 제공되지 않았습니다." }, status: :bad_request
        end

        if current_user.update(push_token: token)
          render json: {
            success: true,
            message: "푸시 토큰이 업데이트되었습니다."
          }
        else
          render json: {
            error: "푸시 토큰 업데이트에 실패했습니다."
          }, status: :unprocessable_entity
        end
      end

      # 알림 설정 조회
      def settings
        render json: {
          push_enabled: current_user.push_enabled,
          message_push_enabled: current_user.message_push_enabled,
          broadcast_push_enabled: current_user.broadcast_push_enabled
        }
      end

      # 알림 설정 업데이트
      def update_settings
        if current_user.update(notification_settings_params)
          render json: {
            success: true,
            message: "알림 설정이 업데이트되었습니다.",
            settings: {
              push_enabled: current_user.push_enabled,
              message_push_enabled: current_user.message_push_enabled,
              broadcast_push_enabled: current_user.broadcast_push_enabled
            }
          }
        else
          render json: {
            error: "알림 설정 업데이트에 실패했습니다.",
            errors: current_user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def set_notification
        @notification = current_user.notifications.find_by(id: params[:id])

        unless @notification
          render json: { error: "알림을 찾을 수 없습니다." }, status: :not_found
        end
      end

      def notification_settings_params
        params.permit(:push_enabled, :message_push_enabled, :broadcast_push_enabled)
      end

      def format_notification(notification)
        {
          id: notification.id,
          type: notification.notification_type,
          title: notification.title,
          body: notification.body,
          read: notification.read,
          created_at: notification.created_at,
          formatted_date: notification.created_at.strftime("%Y년 %m월 %d일 %H:%M"),
          metadata: notification.metadata
        }
      end
    end
  end
end
