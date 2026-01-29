module Api
  class BroadcastsController < BaseController
    before_action :authorize_request

    def index
      begin
        @broadcasts = current_user.broadcasts.order(created_at: :desc).limit(50)

        render json: {
          broadcasts: @broadcasts.map { |broadcast| broadcast_response(broadcast) }
        }
      rescue => e
        Rails.logger.error("방송 목록 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "방송 목록을 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    def received
      begin
        received_broadcasts = Broadcast.joins(:broadcast_recipients)
                                     .where(broadcast_recipients: { recipient_id: current_user.id })
                                     .where("broadcasts.created_at > ?", 6.days.ago)
                                     .order(created_at: :desc)
                                     .limit(50)

        render json: {
          broadcasts: received_broadcasts.map do |broadcast|
            recipient = broadcast.broadcast_recipients.find_by(recipient_id: current_user.id)
            broadcast_response(broadcast).merge(
              status: recipient.status,
              received_at: recipient.created_at
            )
          end
        }
      rescue => e
        Rails.logger.error("수신 방송 목록 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "수신 방송 목록을 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    def create
      result = Broadcasts::CreateService.new(
        user: current_user,
        audio: broadcast_params[:audio],
        content: broadcast_params[:text] || broadcast_params[:content],
        recipient_count: broadcast_params[:recipient_count]
      ).call

      if result.success?
        render json: {
          message: "방송이 성공적으로 전송되었습니다.",
          broadcast: broadcast_response(result.broadcast)
        }, status: :created
      else
        Rails.logger.warn("방송 생성 실패: #{result.error}")
        render json: { error: result.error }, status: :unprocessable_entity
      end
    rescue ActionController::ParameterMissing => e
      Rails.logger.warn("파라미터 누락: #{e.message}")
      render json: { error: "필수 파라미터가 누락되었습니다." }, status: :bad_request
    rescue => e
      Rails.logger.error("방송 생성 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
      render json: { error: "방송을 전송하는 중 오류가 발생했습니다." }, status: :internal_server_error
    end

    def show
      begin
        @broadcast = Broadcast.find(params[:id])

        unless @broadcast.user_id == current_user.id
          return render json: { error: "권한이 없습니다." }, status: :forbidden
        end

        recipients_info = @broadcast.broadcast_recipients.includes(:user).map do |recipient|
          {
            user_id: recipient.user_id,
            nickname: recipient.user.nickname,
            status: recipient.status,
            received_at: recipient.created_at,
            has_conversation: recipient.conversation_exists?
          }
        end

        stats = {
          total_recipients: recipients_info.count,
          delivered: recipients_info.count { |r| r[:status] == "delivered" },
          read: recipients_info.count { |r| r[:status] == "read" },
          replied: recipients_info.count { |r| r[:status] == "replied" }
        }

        render json: {
          broadcast: broadcast_response(@broadcast),
          recipients: recipients_info,
          stats: stats
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "브로드캐스트를 찾을 수 없습니다." }, status: :not_found
      rescue => e
        Rails.logger.error("브로드캐스트 상세 조회 중 오류: #{e.message}")
        render json: { error: "조회 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    def mark_as_read
      begin
        broadcast = Broadcast.find(params[:id])
        recipient = broadcast.broadcast_recipients.find_by(recipient_id: current_user.id)

        unless recipient
          return render json: { error: "이 브로드캐스트의 수신자가 아닙니다." }, status: :forbidden
        end

        if recipient.update(status: "read")
          render json: { message: "브로드캐스트가 읽음으로 표시되었습니다." }, status: :ok
        else
          render json: { error: "상태 업데이트에 실패했습니다." }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "브로드캐스트를 찾을 수 없습니다." }, status: :not_found
      rescue => e
        Rails.logger.error("브로드캐스트 읽음 처리 중 오류: #{e.message}")
        render json: { error: "읽음 처리 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    def reply
      Rails.logger.info("방송 답장 요청: 사용자 ID #{current_user.id}, 방송 ID #{params[:id]}")

      result = message_service.reply_to_broadcast(params[:id], reply_params)

      if result.success?
        broadcast = Broadcast.find(params[:id])
        PushNotificationWorker.perform_async("broadcast_reply", broadcast.id, current_user.id)

        render json: {
          message: "답장이 성공적으로 전송되었습니다.",
          conversation: {
            id: result.message[:conversation_id],
            with_user: {
              id: broadcast.user_id,
              nickname: broadcast.user.nickname
            }
          }
        }, status: :ok
      else
        status = case result.error
                 when "권한이 없습니다." then :forbidden
                 when "브로드캐스트를 찾을 수 없습니다." then :not_found
                 else :unprocessable_entity
                 end
        render json: { error: result.error }, status: status
      end
    end

    private

    def broadcast_params
      params.require(:broadcast).permit(:audio, :text, :content, :recipient_count)
    end

    def broadcast_response(broadcast)
      {
        id: broadcast.id,
        content: broadcast.content,
        text: broadcast.text,
        created_at: broadcast.created_at,
        user: {
          id: broadcast.user.id,
          nickname: broadcast.user.nickname
        }
      }
    end

    def message_service
      @message_service ||= MessageService.new(current_user)
    end

    def reply_params
      params.permit(:voice_file, :message_type)
    end
  end
end
