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
      
      # 음성 파일 첨부 확인 (기본은 음성 메시지로 가정)
      message_type = params[:message_type] || "voice"
      
      # 메시지 객체 초기화
      message = conversation.messages.new(
        sender_id: current_user.id,
        message_type: message_type
      )
      
      # 메시지 타입에 따른 처리
      case message_type
      when "voice"
        # 음성 파일 검증
        unless params[:voice_file].present?
          return render json: { error: "음성 파일이 필요합니다." }, status: :bad_request
        end
        
        # 음성 파일 로깅
        Rails.logger.info("음성 파일 첨부됨: #{params[:voice_file].original_filename}")
        Rails.logger.info("음성 파일 타입: #{params[:voice_file].content_type}")
        Rails.logger.info("음성 파일 크기: #{params[:voice_file].size} 바이트")
        
        # 음성 파일 첨부
        begin
          message.voice_file.attach(params[:voice_file])
          
          # 첨부 확인
          if !message.voice_file.attached?
            return render json: { error: "음성 파일 첨부에 실패했습니다." }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("음성 파일 첨부 중 오류: #{e.message}")
          return render json: { error: "음성 파일 처리 중 오류가 발생했습니다: #{e.message}" }, status: :unprocessable_entity
        end
        
      when "text"
        # 텍스트 메시지 처리
        unless params[:content].present?
          return render json: { error: "텍스트 내용이 필요합니다." }, status: :bad_request
        end
        message.content = params[:content]
        
      when "image"
        # 이미지 파일 처리
        unless params[:image_file].present?
          return render json: { error: "이미지 파일이 필요합니다." }, status: :bad_request
        end
        
        # 이미지 파일 첨부
        begin
          message.image_file.attach(params[:image_file])
          
          # 첨부 확인
          if !message.image_file.attached?
            return render json: { error: "이미지 파일 첨부에 실패했습니다." }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("이미지 파일 첨부 중 오류: #{e.message}")
          return render json: { error: "이미지 파일 처리 중 오류가 발생했습니다: #{e.message}" }, status: :unprocessable_entity
        end
      else
        return render json: { error: "지원하지 않는 메시지 타입입니다." }, status: :bad_request
      end
      
      # 메시지 저장
      if message.save
        # conversation.touch로 updated_at 갱신
        conversation.touch
        
        # 캐시 무효화
        Rails.cache.delete("conversation-messages-#{conversation.id}")
        Rails.cache.delete("conversations-user-#{current_user.id}")
        
        # 대화 상대방의 캐시도 무효화
        receiver_id = (conversation.user_a_id == current_user.id) ? conversation.user_b_id : conversation.user_a_id
        Rails.cache.delete("conversations-user-#{receiver_id}")
        
        # 메시지 전송 성공
        render json: {
          success: true,
          message: "메시지가 전송되었습니다.",
          data: message.as_json(include: { sender: { only: [:id, :nickname] } })
        }, status: :created
      else
        # 메시지 저장 실패
        render json: { error: message.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    private

    def participant?(conversation)
      [conversation.user_a_id, conversation.user_b_id].include?(current_user.id)
    end
  end
end
