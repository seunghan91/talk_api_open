module Api
  class MessagesController < BaseController
    before_action :authorize_request

    def create
      # 로그 추가
      Rails.logger.info("메시지 전송 요청 - params: #{params.inspect}")

      # 파라미터 검사
      unless message_params[:receiver_id].present? && message_params[:content].present?
        return render json: { error: "수신자 ID와 메시지 내용은 필수입니다." }, status: :bad_request
      end

      # 대화를 찾거나 새로 생성
      begin
        # 새로운 헬퍼 메서드 사용
        conversation = Conversation.find_or_create_conversation(current_user.id, message_params[:receiver_id])

        # 메시지 생성
        message = conversation.messages.create!(
          sender_id: current_user.id,
          content: message_params[:content],
          message_type: message_params[:message_type] || "text"
        )

        # 캐시 무효화
        Rails.cache.delete("conversation-messages-#{conversation.id}")
        Rails.cache.delete("conversations-user-#{current_user.id}")
        Rails.cache.delete("conversations-user-#{message_params[:receiver_id]}")

        # 응답
        render json: {
          success: true,
          message: "메시지가 전송되었습니다.",
          data: {
            conversation_id: conversation.id,
            message: message.as_json(include: { sender: { only: [ :id, :nickname ] } })
          }
        }, status: :created
      rescue => e
        Rails.logger.error("메시지 전송 실패: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        render json: { error: "메시지 전송 중 오류가 발생했습니다: #{e.message}" }, status: :internal_server_error
      end
    end

    private

    def message_params
      params.require(:message).permit(:receiver_id, :content, :message_type)
    end
  end
end
