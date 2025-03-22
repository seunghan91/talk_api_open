module Api
  module V1
    class ConversationsController < Api::V1::BaseController
      before_action :authorize_request
      
      # 사용자의 대화 목록 조회
      def index
        begin
          # 유저의 모든 대화 목록을 찾음 (자신이 user_a이거나 user_b인 경우)
          @conversations = Conversation.where("user_a_id = ? OR user_b_id = ?", current_user.id, current_user.id)
                                     .order(updated_at: :desc)
          
          # 대화 목록을 응답 형식에 맞춰 변환
          formatted_conversations = @conversations.map do |conversation|
            {
              id: conversation.id,
              with_user: user_info_for_conversation(conversation),
              last_message: last_message_for_conversation(conversation),
              unread_count: conversation.messages.where.not(sender_id: current_user.id)
                                      .where(read_at: nil).count,
              favorited: conversation.favorited_by?(current_user.id),
              updated_at: conversation.updated_at
            }
          end
          
          render json: { conversations: formatted_conversations }
        rescue => e
          Rails.logger.error("대화 목록 조회 오류: #{e.message}")
          render json: { error: "대화 목록을 불러오는 데 실패했습니다." }, status: :internal_server_error
        end
      end
      
      # 특정 대화 및 메시지 조회
      def show
        begin
          # 대화 찾기
          @conversation = Conversation.find(params[:id])
          
          # 사용자가 이 대화에 참여하고 있는지 확인
          unless @conversation.user_a_id == current_user.id || @conversation.user_b_id == current_user.id
            return render json: { error: "대화를 볼 수 없습니다." }, status: :forbidden
          end
          
          # 대화 상대 정보
          other_user = @conversation.user_a_id == current_user.id ? 
                      User.find(@conversation.user_b_id) : 
                      User.find(@conversation.user_a_id)
          
          # 메시지 가져오기 (양방향 통신 지원)
          direct_messages = @conversation.messages
                                        .includes(:sender)
                                        .order(created_at: :desc)
                                        .limit(50)
                                        
          # 브로드캐스트 메시지도 포함 (개인 브로드캐스트 + 전체 브로드캐스트)
          # 후에 추가 필요, 현재는 직접적인 대화 메시지만 포함
          
          # 상대방이 보낸 메시지 읽음 처리
          @conversation.messages.where(sender_id: other_user.id)
                              .where(read_at: nil)
                              .update_all(read_at: Time.current)
          
          # 브로드캐스트 메시지를 포함한 전체 메시지 (양방향 통신)
          all_messages = direct_messages.map do |message|
            {
              id: message.id,
              sender_id: message.sender_id,
              sender_nickname: message.sender.nickname,
              voice_url: message.voice_file.attached? ? url_for(message.voice_file) : nil,
              text: message.text,
              created_at: message.created_at,
              read_at: message.read_at
            }
          end
          
          # 응답으로 대화 정보와 메시지 목록 전송
          render json: {
            conversation: {
              id: @conversation.id,
              with_user: {
                id: other_user.id,
                nickname: other_user.nickname,
                profile_image: other_user.profile_image.attached? ? url_for(other_user.profile_image) : nil
              },
              favorited: @conversation.favorited_by?(current_user.id)
            },
            messages: all_messages
          }
        rescue ActiveRecord::RecordNotFound
          render json: { error: "대화를 찾을 수 없습니다." }, status: :not_found
        rescue => e
          Rails.logger.error("대화 조회 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "대화를 불러오는 데 실패했습니다." }, status: :internal_server_error
        end
      end
      
      # 대화 메시지 전송
      def send_message
        begin
          # 대화 찾기
          @conversation = Conversation.find(params[:id])
          
          # 사용자가 이 대화에 참여하고 있는지 확인
          unless @conversation.user_a_id == current_user.id || @conversation.user_b_id == current_user.id
            return render json: { error: "이 대화에 메시지를 보낼 수 없습니다." }, status: :forbidden
          end
          
          # 메시지 생성
          @message = @conversation.messages.new(
            sender_id: current_user.id,
            text: params[:text]
          )
          
          # 음성 파일 첨부가 있을 경우
          if params[:voice_file].present?
            begin
              @message.voice_file.attach(params[:voice_file])
            rescue => e
              Rails.logger.error("음성 파일 첨부 오류: #{e.message}")
              return render json: { error: "음성 파일 첨부에 실패했습니다." }, status: :unprocessable_entity
            end
          end
          
          # 메시지 저장
          if @message.save
            # 상대방에게 푸시 알림 전송
            other_user_id = @conversation.user_a_id == current_user.id ? 
                          @conversation.user_b_id : 
                          @conversation.user_a_id
                          
            PushNotificationWorker.perform_async('new_message', @message.id, other_user_id)
            
            # 성공 응답
            render json: {
              message: {
                id: @message.id,
                sender_id: @message.sender_id,
                text: @message.text,
                voice_url: @message.voice_file.attached? ? url_for(@message.voice_file) : nil,
                created_at: @message.created_at
              }
            }, status: :created
          else
            render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: "대화를 찾을 수 없습니다." }, status: :not_found
        rescue => e
          Rails.logger.error("메시지 전송 오류: #{e.message}")
          render json: { error: "메시지 전송에 실패했습니다." }, status: :internal_server_error
        end
      end
      
      # 대화 즐겨찾기 추가
      def favorite
        toggle_favorite(true)
      end
      
      # 대화 즐겨찾기 제거
      def unfavorite
        toggle_favorite(false)
      end
      
      # 대화 삭제
      def destroy
        begin
          # 대화 찾기
          @conversation = Conversation.find(params[:id])
          
          # 사용자가 이 대화에 참여하고 있는지 확인
          unless @conversation.user_a_id == current_user.id || @conversation.user_b_id == current_user.id
            return render json: { error: "이 대화를 삭제할 권한이 없습니다." }, status: :forbidden
          end
          
          # 사용자가 user_a인지 user_b인지에 따라 다른 필드 업데이트
          if @conversation.user_a_id == current_user.id
            @conversation.update(deleted_by_a: true)
          else
            @conversation.update(deleted_by_b: true)
          end
          
          # 양쪽 모두 삭제했다면 실제로 삭제
          if @conversation.deleted_by_a && @conversation.deleted_by_b
            @conversation.destroy
            render json: { message: "대화가 완전히 삭제되었습니다." }
          else
            render json: { message: "대화가 목록에서 제거되었습니다." }
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: "대화를 찾을 수 없습니다." }, status: :not_found
        rescue => e
          Rails.logger.error("대화 삭제 오류: #{e.message}")
          render json: { error: "대화 삭제에 실패했습니다." }, status: :internal_server_error
        end
      end
      
      private
      
      # 대화 상대방 정보 조회
      def user_info_for_conversation(conversation)
        other_user_id = conversation.user_a_id == current_user.id ? 
                      conversation.user_b_id : 
                      conversation.user_a_id
                      
        other_user = User.find_by(id: other_user_id)
        return nil unless other_user
        
        {
          id: other_user.id,
          nickname: other_user.nickname,
          profile_image: other_user.profile_image.attached? ? url_for(other_user.profile_image) : nil
        }
      end
      
      # 마지막 메시지 정보 조회
      def last_message_for_conversation(conversation)
        last_message = conversation.messages.order(created_at: :desc).first
        return nil unless last_message
        
        {
          id: last_message.id,
          sender_id: last_message.sender_id,
          text: last_message.text,
          has_voice: last_message.voice_file.attached?,
          created_at: last_message.created_at
        }
      end
      
      # 즐겨찾기 토글 처리
      def toggle_favorite(favorite)
        begin
          # 대화 찾기
          @conversation = Conversation.find(params[:id])
          
          # 사용자가 이 대화에 참여하고 있는지 확인
          unless @conversation.user_a_id == current_user.id || @conversation.user_b_id == current_user.id
            return render json: { error: "이 대화에 대한 권한이 없습니다." }, status: :forbidden
          end
          
          # 사용자가 user_a인지 user_b인지에 따라 다른 필드 업데이트
          if @conversation.user_a_id == current_user.id
            @conversation.update(favorited_by_a: favorite)
          else
            @conversation.update(favorited_by_b: favorite)
          end
          
          render json: { 
            message: favorite ? "대화가 즐겨찾기에 추가되었습니다." : "대화가 즐겨찾기에서 제거되었습니다.",
            favorited: favorite
          }
        rescue ActiveRecord::RecordNotFound
          render json: { error: "대화를 찾을 수 없습니다." }, status: :not_found
        rescue => e
          action = favorite ? "추가" : "제거"
          Rails.logger.error("즐겨찾기 #{action} 오류: #{e.message}")
          render json: { error: "즐겨찾기 #{action}에 실패했습니다." }, status: :internal_server_error
        end
      end
    end
  end
end 