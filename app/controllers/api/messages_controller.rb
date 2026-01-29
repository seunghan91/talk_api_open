module Api
  class MessagesController < BaseController
    before_action :authorize_request

    def create
      Rails.logger.info("메시지 전송 요청 - params: #{params.inspect}")

      # 파라미터 검사
      unless message_params[:receiver_id].present?
        return render json: { error: "수신자 ID는 필수입니다." }, status: :bad_request
      end

      # 대화를 찾거나 새로 생성
      conversation_result = conversation_service.find_or_create_conversation(message_params[:receiver_id])
      
      unless conversation_result.success?
        return render json: { error: conversation_result.error }, status: :unprocessable_entity
      end

      # 메시지 전송
      send_params = {
        content: message_params[:content],
        message_type: message_params[:message_type] || "text",
        voice_file: params[:voice_file],
        image_file: params[:image_file]
      }

      result = message_service.send_message(conversation_result.conversation.id, send_params)

      if result.success?
        render json: {
          success: true,
          message: "메시지가 전송되었습니다.",
          data: {
            conversation_id: conversation_result.conversation.id,
            message: result.message
          }
        }, status: :created
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end

    private

    def conversation_service
      @conversation_service ||= ConversationService.new(current_user)
    end

    def message_service
      @message_service ||= MessageService.new(current_user)
    end

    def message_params
      params.require(:message).permit(:receiver_id, :content, :message_type)
    end
  end
end
