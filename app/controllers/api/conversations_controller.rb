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
    return head :forbidden unless participant?(conversation)
    
    # 로깅 추가
    Rails.logger.info("메시지 전송 요청: 사용자 ID #{current_user.id}, 대화 ID #{params[:id]}")
    
    # 음성 파일 첨부 확인
    unless params[:voice_file].present?
      Rails.logger.warn("음성 파일 없음: 메시지 전송 실패")
      return render json: { error: "음성 파일이 필요합니다." }, status: :bad_request
    end
    
    # 음성 파일 로깅
    Rails.logger.info("음성 파일 첨부됨: #{params[:voice_file].original_filename}")
    Rails.logger.info("음성 파일 타입: #{params[:voice_file].content_type}")
    Rails.logger.info("음성 파일 크기: #{params[:voice_file].size} 바이트")
    
    message = conversation.messages.new(sender_id: @current_user.id)
    
    begin
      # 음성 파일 직접 첨부 (무음 구간 트리밍 없이)
      message.voice_file.attach(params[:voice_file])
      
      # 첨부 확인
      if !message.voice_file.attached?
        Rails.logger.error("메시지 음성 파일 첨부 실패")
        return render json: { error: "음성 파일 첨부에 실패했습니다." }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error("메시지 음성 파일 첨부 중 오류: #{e.message}")
      return render json: { error: "음성 파일 처리 중 오류가 발생했습니다: #{e.message}" }, status: :unprocessable_entity
    end
    
    if message.save
      # conversation.touch → updated_at 갱신
      conversation.touch
      
      # 캐시 무효화
      Rails.cache.delete("conversation-messages-#{conversation.id}")
      Rails.cache.delete("conversations-user-#{current_user.id}")
      
      # 상대방의 대화 목록 캐시도 무효화
      other_user_id = (conversation.user_a_id == current_user.id) ? conversation.user_b_id : conversation.user_a_id
      Rails.cache.delete("conversations-user-#{other_user_id}")
      
      # 비동기 메시지 전송 처리
      MessageDeliveryWorker.perform_async(message.id)
      
      # 성공 로깅
      Rails.logger.info("메시지 전송 성공: 메시지 ID #{message.id}")
      
      render json: { 
        message: "메시지 전송 완료", 
        message_id: message.id,
        conversation_id: conversation.id
      }, status: :ok
    else
      # 실패 로깅
      Rails.logger.error("메시지 전송 실패: #{message.errors.full_messages}")
      render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def participant?(conversation)
    [conversation.user_a_id, conversation.user_b_id].include?(current_user.id)
  end
end
