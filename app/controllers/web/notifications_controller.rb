# app/controllers/web/notifications_controller.rb
module Web
  class NotificationsController < Web::BaseController
    before_action :authenticate_user!

    # GET /notifications
    def index
      notifications = current_user.notifications
        .order(created_at: :desc)
        .page(params[:page])
        .per(20)

      render inertia: "Notifications/Index", props: {
        notifications: notifications.map { |n| serialize_notification(n) },
        pagination: pagination_meta(notifications),
        unread_count: current_user.notifications.unread.count
      }
    end

    # PATCH /notifications/mark_all_read
    def mark_all_read
      current_user.notifications.unread.update_all(read: true, read_at: Time.current)
      redirect_to "/notifications", notice: "모든 알림을 읽음 처리했습니다."
    end

    private

    def serialize_notification(notification)
      {
        id: notification.id,
        title: notification.title,
        body: notification.body,
        notification_type: notification.notification_type,
        read: notification.read,
        data: notification.respond_to?(:data) ? notification.data : nil,
        created_at: notification.created_at.iso8601
      }
    end
  end
end
