# app/controllers/api/conversations_controller.rb
module Api
  class ConversationsController < BaseController
    before_action :authorize_request

    def index
      Rails.logger.info("대화 목록 조회 시작: 사용자 ID #{current_user.id}")

      result = conversation_service.list_conversations

      if result.success?
        render json: {
          success: true,
          conversations: result.conversation,
          request_id: request.request_id || SecureRandom.uuid
        }
      else
        Rails.logger.error("대화 목록 조회 실패: #{result.error}")
        render json: {
          success: false,
          error: result.error,
          request_id: request.request_id || SecureRandom.uuid
        }, status: :internal_server_error
      end
    end

    def show
      result = conversation_service.show_conversation(params[:id])

      if result.success?
        render json: {
          conversation: result.conversation,
          messages: result.message.as_json(include: { sender: { only: [:id, :nickname] } })
        }
      else
        status = result.error == "권한이 없습니다." ? :forbidden : :not_found
        render json: { error: result.error }, status: status
      end
    end

    def destroy
      result = conversation_service.delete_conversation(params[:id])

      if result.success?
        render json: { success: true, message: result.message }
      else
        status = result.error == "권한이 없습니다." ? :forbidden : :not_found
        render json: { error: result.error }, status: status
      end
    end

    def favorite
      result = conversation_service.toggle_favorite(params[:id])

      if result.success?
        render json: { message: result.message }
      else
        status = result.error == "권한이 없습니다." ? :forbidden : :not_found
        render json: { error: result.error }, status: status
      end
    end

    def unfavorite
      favorite
    end

    def send_message
      result = message_service.send_message(params[:id], message_params)

      if result.success?
        render json: {
          success: true,
          message: "메시지가 전송되었습니다.",
          data: result.message
        }, status: :created
      else
        status = case result.error
                 when "권한이 없습니다." then :forbidden
                 when "대화를 찾을 수 없습니다." then :not_found
                 else :unprocessable_entity
                 end
        render json: { error: result.error }, status: status
      end
    end

    def unread_count
      begin
        conversation = Conversation.find(params[:id])

        unless participant?(conversation)
          return render json: { error: "권한이 없습니다." }, status: :forbidden
        end

        unread_count = conversation.messages
                                  .where(sender_id: conversation.other_user_id(current_user.id))
                                  .where(read: false)
                                  .count

        render json: {
          conversation_id: conversation.id,
          unread_count: unread_count
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "대화방을 찾을 수 없습니다." }, status: :not_found
      rescue => e
        Rails.logger.error("읽지 않은 메시지 수 조회 중 오류: #{e.message}")
        render json: { error: "조회 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    private

    def conversation_service
      @conversation_service ||= ConversationService.new(current_user)
    end

    def message_service
      @message_service ||= MessageService.new(current_user)
    end

    def participant?(conversation)
      [conversation.user_a_id, conversation.user_b_id].include?(current_user.id)
    end

    def message_params
      params.permit(:message_type, :content, :voice_file, :image_file, :broadcast_id)
    end
  end
end
