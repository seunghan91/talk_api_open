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
                next nil # 상대방 정보 없으면 대화 제외
              end

              # 마지막 메시지 조회 - 삭제되지 않은 메시지만 고려 (find_last_message 내부 로직에 따라)
              last_message = find_last_message(conversation)

              # 마지막 메시지 포맷팅 또는 기본값 설정
              formatted_last_message = if last_message
                                     format_last_message(last_message)
              else
                                     # 메시지가 없거나 모두 삭제된 경우 빈 음성 메시지로 표시 (텍스트 제거)
                                     Rails.logger.info("마지막 메시지 없음 또는 모두 삭제됨: 대화 ID #{conversation.id}")
                                     {
                                       id: nil,
                                       content: nil, # 텍스트 내용 제거
                                       audio_url: nil, # 오디오 URL 없음
                                       sender_id: nil,
                                       created_at: conversation.updated_at, # 대화 업데이트 시간을 기준으로
                                       is_read: true, # 안 읽음 카운트가 0이 되도록
                                       message_type: "voice" # 항상 음성 메시지 타입
                                     }
              end

              # 안 읽은 메시지 수 계산
              unread_count = count_unread_messages(conversation)

              {
                id: conversation.id,
                with_user: {
                  id: other_user.id,
                  nickname: other_user.nickname,
                  profile_image: nil # 프로필 이미지 기능 미구현
                },
                last_message: formatted_last_message,
                unread_count: unread_count,
                favorited: conversation.favorited_by?(current_user.id),
                updated_at: conversation.updated_at
              }
            rescue => e
              Rails.logger.error("대화 정보 변환 중 오류: 대화 ID #{conversation.id}, 오류: #{e.message}\n#{e.backtrace.join("\n")}")
              next nil # 오류 발생 시 해당 대화 제외
            end
          end.compact # nil 값 제거 (여전히 필요)

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
          unless @conversation.visible_to?(current_user.id)
            Rails.logger.warn("삭제된 대화 접근: 사용자 ID #{current_user.id}가 삭제한 대화 ID #{conversation_id}에 접근 시도")
            return render json: {
              error: "삭제된 대화입니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :gone
          end

          # 상대방 정보 조회
          other_user_id = @conversation.other_user_id(current_user.id)
          other_user = User.find_by(id: other_user_id)

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
              profile_image: nil # 프로필 이미지 기능 미구현
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

          # 음성 파일 첨부 확인
          unless params[:voice_file].present?
            Rails.logger.error("음성 파일 없음: 메시지 전송 실패")
            return render json: {
              error: "음성 파일이 필요합니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :bad_request
          end

          # 메시지 생성
          @message = @conversation.messages.new(
            sender_id: current_user.id,
            message_type: "voice"
          )

          # 음성 파일 첨부
          begin
            @message.voice_file.attach(params[:voice_file])
          rescue => e
            Rails.logger.error("음성 파일 첨부 오류: #{e.message}")
            return render json: {
              error: "음성 파일 첨부에 실패했습니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :unprocessable_entity
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
                voice_url: @message.voice_file.attached? ? url_for(@message.voice_file) : nil,
                created_at: @message.created_at
              },
              request_id: request.request_id || SecureRandom.uuid
            }, status: :created
          else
            render json: {
              errors: @message.errors.full_messages,
              request_id: request.request_id || SecureRandom.uuid
            }, status: :unprocessable_entity
          end
        rescue ActiveRecord::RecordNotFound
          render json: {
            error: "대화를 찾을 수 없습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :not_found
        rescue => e
          Rails.logger.error("메시지 전송 오류: #{e.message}")
          render json: {
            error: "메시지 전송에 실패했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
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
          # 새로운 스코프와 도우미 메서드 사용
          Conversation.for_user(current_user.id)
                     .select { |conv| conv.visible_to?(current_user.id) }
                     .sort_by(&:updated_at)
                     .reverse
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
                           .where(read: false)
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

          {
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
                is_read: message.read,
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
              is_read: message.read,
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
              is_read: message.read,
              created_at: message.created_at,
              is_broadcast: false,
              message_type: message.message_type || "voice"
            }
          end
        end
      end

      # 읽지 않은 메시지 읽음 처리
      def mark_messages_as_read(messages)
        unread_messages = messages.where.not(sender_id: current_user.id).where(read: false)

        if unread_messages.any?
          unread_messages.update_all(read: true)

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
