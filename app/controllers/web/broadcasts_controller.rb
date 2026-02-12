# app/controllers/web/broadcasts_controller.rb
module Web
  class BroadcastsController < Web::BaseController
    before_action :authenticate_user!

    # GET /broadcasts
    def index
      broadcasts = Broadcast.joins(:broadcast_recipients)
        .where(broadcast_recipients: { user_id: current_user.id })
        .active
        .includes(:user)
        .distinct
        .order(created_at: :desc)
        .page(params[:page])
        .per(20)

      render inertia: "Broadcasts/Index", props: {
        broadcasts: broadcasts.map { |b| serialize_broadcast(b) },
        pagination: pagination_meta(broadcasts)
      }
    end

    # GET /broadcasts/:id
    def show
      broadcast = Broadcast.find(params[:id])

      render inertia: "Broadcasts/Show", props: {
        broadcast: serialize_broadcast_detail(broadcast)
      }
    end

    # GET /broadcasts/new
    def new
      render inertia: "Broadcasts/Create"
    end

    # POST /broadcasts
    def create
      service = ::Broadcasts::CreateService.new(
        user: current_user,
        audio: params[:audio],
        content: params[:content],
        recipient_count: params[:recipient_count]
      )
      result = service.call

      if result.success?
        redirect_to "/broadcasts", notice: "브로드캐스트가 전송되었습니다!"
      else
        redirect_to "/broadcasts/new", inertia: { errors: { audio: result.error } }
      end
    rescue => e
      Rails.logger.error("브로드캐스트 생성 실패: #{e.message}")
      redirect_to "/broadcasts/new", alert: "브로드캐스트 전송에 실패했습니다."
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
        created_at: broadcast.created_at.iso8601
      }
    rescue => e
      nil
    end

    def serialize_broadcast_detail(broadcast)
      {
        id: broadcast.id,
        user: {
          id: broadcast.user.id,
          nickname: broadcast.user.nickname
        },
        duration: broadcast.duration,
        audio_url: broadcast.audio.attached? ? url_for(broadcast.audio) : nil,
        created_at: broadcast.created_at.iso8601,
        recipients_count: broadcast.broadcast_recipients.count
      }
    end
  end
end
