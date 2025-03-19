# app/controllers/api/conversations_controller.rb
module Api
  class ConversationsController < BaseController
    before_action :authorize_request

    def index
      # 사용자별 대화 목록 캐싱 (1분 유효)
      @conversations = Rails.cache.fetch("conversations-user-#{current_user.id}", expires_in: 1.minute) do
        Conversation.where("user_a_id = ? OR user_b_id = ?", current_user.id, current_user.id)
                    .order(updated_at: :desc)
                    .includes(:user_a, :user_b)
                    .to_a
      end
      
      render json: @conversations, include: {
        user_a: { only: [:id, :nickname, :gender] },
        user_b: { only: [:id, :nickname, :gender] }
      }
    end

    def show
      conversation = Conversation.find(params[:id])
      unless participant?(conversation)
        return render json: { error: "권한이 없습니다." }, status: :forbidden
      end
      
      # 대화별 메시지 캐싱 (30초 유효)
      messages = Rails.cache.fetch("conversation-messages-#{conversation.id}", expires_in: 30.seconds) do
        conversation.messages.order(created_at: :asc).includes(:sender).to_a
      end
      
      render json: { 
        conversation: conversation,
        messages: messages.as_json(include: { sender: { only: [:id, :nickname] } })
      }
    end

    def destroy
      conversation = Conversation.find(params[:id])
      if participant?(conversation)
        conversation.destroy
        render json: { message: "대화방이 삭제되었습니다." }
      else
        render json: { error: "권한이 없습니다." }, status: :forbidden
      end
    end

    def favorite
      conversation = Conversation.find(params[:id])
      return head :forbidden unless participant?(conversation)

      conversation.update(favorite: true)
      render json: { message: "즐겨찾기 등록 완료" }
    end

    def unfavorite
      conversation = Conversation.find(params[:id])
      return head :forbidden unless participant?(conversation)

      conversation.update(favorite: false)
      render json: { message: "즐겨찾기 해제 완료" }
    end

    def send_message
      conversation = Conversation.find(params[:id])
      
      # 대화방 참여자 확인
      unless participant?(conversation)
        return render json: { error: "권한이 없습니다." }, status: :forbidden
      end
      
      # 메시지 생성
      message = conversation.messages.new(
        sender_id: current_user.id,
        content: params[:content],
        message_type: params[:message_type] || "text"
      )
      
      if message.save
        # 캐시 무효화
        Rails.cache.delete("conversation-messages-#{conversation.id}")
        Rails.cache.delete("conversations-user-#{current_user.id}")
        
        # 대화 상대방 ID 찾기
        receiver_id = (conversation.user_a_id == current_user.id) ? conversation.user_b_id : conversation.user_a_id
        Rails.cache.delete("conversations-user-#{receiver_id}")
        
        render json: {
          success: true,
          message: "메시지가 전송되었습니다.",
          data: message.as_json(include: { sender: { only: [:id, :nickname] } })
        }, status: :created
      else
        render json: { error: message.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    private

    def participant?(conversation)
      [conversation.user_a_id, conversation.user_b_id].include?(current_user.id)
    end
  end
end
