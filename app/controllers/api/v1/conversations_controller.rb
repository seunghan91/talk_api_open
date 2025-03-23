module Api
  module V1
    class ConversationsController < Api::V1::BaseController
      before_action :authorize_request

      # 사용자의 대화 목록 조회
      def index
        begin
          Rails.logger.info("대화 목록 조회 시작: 사용자 ID #{current_user.id}")
          
          # 유저의 모든 대화 목록을 찾음 (자신이 user_a이거나 user_b인 경우)
          # 삭제되지 않은 대화만 가져오기
          @conversations = find_user_conversations
          
          unless @conversations
            Rails.logger.error("대화 목록 조회 실패: 사용자 ID #{current_user.id}의 대화를 찾을 수 없음")
            return render json: { error: "대화 목록을 불러오는 데 실패했습니다." }, status: :not_found
          end

          Rails.logger.info("대화 목록 찾음: #{@conversations.count}개")

          # 대화 목록을 응답 형식에 맞춰 변환
          formatted_conversations = @conversations.map do |conversation|
            begin
              # 상대방 정보 조회
              other_user = find_other_user(conversation)
              
              unless other_user
                Rails.logger.error("대화 상대 조회 실패: 대화 ID #{conversation.id}의 상대방을 찾을 수 없음")
                next nil
              end
              
              # 마지막 메시지 조회 - 삭제되지 않은 메시지만
              last_message = find_last_message(conversation)
              
              # 마지막 메시지가 없는 경우 로그 추가
              unless last_message
                Rails.logger.warn("마지막 메시지 없음: 대화 ID #{conversation.id}")
                next nil # 메시지가 없는 대화는 표시하지 않음
              end
              
              # 브로드캐스트 관련 메시지 처리 보강
              if last_message.broadcast_id.present?
                broadcast = Broadcast.find_by(id: last_message.broadcast_id)
                unless broadcast
                  Rails.logger.warn("브로드캐스트 메시지 처리 실패: 존재하지 않는 브로드캐스트 ID #{last_message.broadcast_id}")
                  # 브로드캐스트가 없더라도 대화는 표시
                end
              end
              
              {
                id: conversation.id,
                with_user: {
                  id: other_user.id,
                  nickname: other_user.nickname,
                  profile_image: other_user.profile_image.attached? ? url_for(other_user.profile_image) : nil
                },
                last_message: format_last_message(last_message),
                unread_count: count_unread_messages(conversation),
                favorited: conversation.favorited_by?(current_user.id),
                updated_at: conversation.updated_at
              }
            rescue => e
              Rails.logger.error("대화 정보 변환 중 오류: #{e.message}\n#{e.backtrace.join("\n")}")
              next nil
            end
          end.compact # nil 값 제거
          
          # 정렬: 마지막 메시지 시간 기준 내림차순
          formatted_conversations.sort_by! { |c| -c[:updated_at].to_i }

          Rails.logger.info("대화 목록 응답 반환: #{formatted_conversations.size}개")

          render json: { 
            conversations: formatted_conversations,
            request_id: request.request_id || SecureRandom.uuid
          }
        rescue => e
          Rails.logger.error("대화 목록 조회 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { 
            error: "대화 목록을 불러오는 데 실패했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      # 특정 대화 및 메시지 조회
      def show
        begin
          conversation_id = params[:id]
          @conversation = Conversation.find_by(id: conversation_id)
          
          unless @conversation
            Rails.logger.error("대화 상세 조회 실패: 대화 ID #{conversation_id}를 찾을 수 없음")
            return render json: { 
              error: "해당 대화를 찾을 수 없습니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :not_found
          end
          
          # 현재 사용자가 대화의 참여자인지 확인
          unless @conversation.user_a_id == current_user.id || @conversation.user_b_id == current_user.id
            Rails.logger.warn("대화 접근 권한 없음: 사용자 ID #{current_user.id}는 대화 ID #{conversation_id}에 접근할 수 없음")
            return render json: { 
              error: "해당 대화에 접근할 권한이 없습니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :forbidden
          end
          
          # 사용자가 삭제한 대화인지 확인
          if (@conversation.user_a_id == current_user.id && @conversation.deleted_by_a) ||
             (@conversation.user_b_id == current_user.id && @conversation.deleted_by_b)
            Rails.logger.warn("삭제된 대화 접근: 사용자 ID #{current_user.id}가 삭제한 대화 ID #{conversation_id}에 접근 시도")
            return render json: { 
              error: "삭제된 대화입니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :gone
          end
          
          # 상대방 정보 조회
          other_user = find_other_user(@conversation)
          
          # 메시지 목록 조회 - 삭제되지 않은 메시지만
          messages = fetch_visible_messages
          
          # 메시지 포맷팅
          formatted_messages = format_messages(messages)
          
          # 읽지 않은 메시지 읽음 처리
          mark_messages_as_read(messages)
          
          render json: {
            id: @conversation.id,
            with_user: {
              id: other_user.id,
              nickname: other_user.nickname,
              profile_image: other_user.profile_image.attached? ? url_for(other_user.profile_image) : nil
            },
            messages: formatted_messages,
            favorited: @conversation.favorited_by?(current_user.id),
            request_id: request.request_id || SecureRandom.uuid
          }
        rescue => e
          Rails.logger.error("대화 상세 조회 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { 
            error: "대화 정보를 불러오는 데 실패했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
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

            PushNotificationWorker.perform_async("new_message", @message.id, other_user_id)

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

      # 사용자의 대화 찾기
      def find_user_conversations
        if current_user.status_active?
          Conversation.where("(user_a_id = ? AND deleted_by_a = ?) OR (user_b_id = ? AND deleted_by_b = ?)", 
                            current_user.id, false, current_user.id, false)
                     .order(updated_at: :desc)
        else
          Rails.logger.warn("비활성 사용자의 대화 목록 요청: 사용자 ID #{current_user.id}, 상태 #{current_user.status}")
          []
        end
      end
      
      # 대화 상대방 찾기
      def find_other_user(conversation)
        other_user_id = conversation.user_a_id == current_user.id ? 
                        conversation.user_b_id : 
                        conversation.user_a_id
                        
        User.find_by(id: other_user_id)
      end
      
      # 마지막 메시지 찾기
      def find_last_message(conversation)
        # 현재 사용자에게 보여야 할 메시지만 가져옴
        message = if current_user.id == conversation.user_a_id
          conversation.messages.where(deleted_by_a: false).order(created_at: :desc).first
        else
          conversation.messages.where(deleted_by_b: false).order(created_at: :desc).first
        end
        
        # 메시지가 없으면 nil 반환
        message
      end
      
      # 읽지 않은 메시지 개수 계산
      def count_unread_messages(conversation)
        conversation.messages.where.not(sender_id: current_user.id)
                           .where(read_at: nil)
                           .count
      end
      
      # 마지막 메시지 포맷팅
      def format_last_message(message)
        return nil unless message
        
        if message.broadcast_id.present?
          sender = User.find_by(id: message.sender_id)
          broadcast = Broadcast.find_by(id: message.broadcast_id)
          
          # 브로드캐스트 정보가 없는 경우 기본값 제공 (삭제된 경우 등)
          unless broadcast
            Rails.logger.warn("브로드캐스트 정보 없음: ID #{message.broadcast_id}")
            return {
              id: message.id,
              sender_id: message.sender_id,
              sender_nickname: sender&.nickname,
              is_broadcast: true,
              broadcast_id: message.broadcast_id,
              text: "브로드캐스트 메시지(삭제됨)",
              has_voice: false,
              created_at: message.created_at,
              message_type: message.message_type || "voice"
            }
          end
          
          return {
            id: message.id,
            sender_id: message.sender_id,
            sender_nickname: sender&.nickname,
            is_broadcast: true,
            broadcast_id: message.broadcast_id,
            text: broadcast&.text || "브로드캐스트 메시지",
            has_voice: broadcast&.audio&.attached?,
            created_at: message.created_at,
            message_type: message.message_type || "voice"
          }
        else
          {
            id: message.id,
            sender_id: message.sender_id,
            text: message.text,
            has_voice: message.voice_file.attached?,
            created_at: message.created_at,
            is_broadcast: false,
            message_type: message.message_type || "voice"
          }
        end
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

      # 메시지 목록 조회 - 삭제되지 않은 메시지만
      def fetch_visible_messages
        if current_user.id == @conversation.user_a_id
          @conversation.messages.where(deleted_by_a: false).order(created_at: :asc)
        else
          @conversation.messages.where(deleted_by_b: false).order(created_at: :asc)
        end
      end
      
      # 메시지 포맷팅
      def format_messages(messages)
        messages.map do |message|
          if message.broadcast_id.present?
            sender = User.find_by(id: message.sender_id)
            broadcast = Broadcast.find_by(id: message.broadcast_id)
            
            # 브로드캐스트 정보가 없는 경우 기본값 제공
            unless broadcast
              Rails.logger.warn("브로드캐스트 정보 없음 (메시지 목록): ID #{message.broadcast_id}")
              next {
                id: message.id,
                sender_id: message.sender_id,
                sender_nickname: sender&.nickname,
                is_broadcast: true,
                broadcast_id: message.broadcast_id,
                text: "브로드캐스트 메시지(삭제됨)",
                has_voice: false,
                voice_url: nil,
                read_at: message.read_at,
                created_at: message.created_at,
                message_type: message.message_type || "voice"
              }
            end
            
            {
              id: message.id,
              sender_id: message.sender_id,
              sender_nickname: sender&.nickname,
              is_broadcast: true,
              broadcast_id: message.broadcast_id,
              text: broadcast&.text || "브로드캐스트 메시지",
              has_voice: broadcast&.audio&.attached?,
              voice_url: broadcast&.audio&.attached? ? url_for(broadcast.audio) : nil,
              read_at: message.read_at,
              created_at: message.created_at,
              message_type: message.message_type || "voice"
            }
          else
            {
              id: message.id,
              sender_id: message.sender_id,
              text: message.text,
              has_voice: message.voice_file.attached?,
              voice_url: message.voice_file.attached? ? url_for(message.voice_file) : nil,
              read_at: message.read_at,
              created_at: message.created_at,
              is_broadcast: false,
              message_type: message.message_type || "voice"
            }
          end
        end
      end
      
      # 읽지 않은 메시지 읽음 처리
      def mark_messages_as_read(messages)
        unread_messages = messages.where.not(sender_id: current_user.id).where(read_at: nil)
        
        if unread_messages.any?
          now = Time.current
          unread_messages.update_all(read_at: now)
          
          # 브로드캐스트 수신자 상태 업데이트
          unread_messages.each do |message|
            if message.broadcast_id.present?
              broadcast_recipient = BroadcastRecipient.find_by(broadcast_id: message.broadcast_id, user_id: current_user.id)
              broadcast_recipient&.update(status: :read) if broadcast_recipient&.delivered?
            end
          end
        end
      end
    end
  end
end
