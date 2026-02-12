# app/controllers/web/home_controller.rb
module Web
  class HomeController < Web::BaseController
    before_action :authenticate_user!

    # GET /
    def index
      broadcasts = Broadcast.joins(:broadcast_recipients)
        .where(broadcast_recipients: { user_id: current_user.id })
        .active
        .includes(:user)
        .distinct
        .order(created_at: :desc)
        .page(params[:page])
        .per(20)

      render inertia: "Home/Index", props: {
        broadcasts: broadcasts.map { |b| serialize_broadcast(b) },
        pagination: pagination_meta(broadcasts)
      }
    rescue => e
      Rails.logger.error("홈 페이지 로드 실패: #{e.message}")
      render inertia: "Home/Index", props: {
        broadcasts: [],
        pagination: { current_page: 1, total_pages: 0, total_count: 0, per_page: 20 }
      }
    end

    private

    def serialize_broadcast(broadcast)
      {
        id: broadcast.id,
        user: {
          id: broadcast.user.id,
          nickname: broadcast.user.nickname
        },
        duration: broadcast.duration,
        audio_url: broadcast.audio.attached? ? url_for(broadcast.audio) : nil,
        created_at: broadcast.created_at.iso8601,
        is_read: broadcast.respond_to?(:read?) ? broadcast.read? : false
      }
    rescue => e
      Rails.logger.error("브로드캐스트 직렬화 실패: #{e.message}")
      nil
    end
  end
end
