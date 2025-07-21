# app/controllers/api/conversations_controller.rb
module Api
  class ConversationsController < BaseController
    before_action :authorize_request

    def index
      begin
        Rails.logger.info("대화 목록 조회 시작: 사용자 ID #{current_user.id}")

        # 성능 모니터링 시작
        start_time = Time.now

        # not_deleted_for 스코프 활용하여 삭제된 대화 제외
        Rails.logger.debug("대화 목록 DB에서 조회 중...")
        @conversations = Conversation
          .for_user(current_user.id)
          .not_deleted_for(current_user.id)
          .order(updated_at: :desc)
          .includes(:user_a, :user_b, messages: [ :broadcast ])

        # 성능 모니터링 - 쿼리 완료 시간
        query_time = Time.now - start_time
        Rails.logger.debug("대화 목록 쿼리 완료: #{query_time.round(3)}초 소요")

        # 정렬 전 대화 ID 로깅 - 디버깅용
        conversation_ids = @conversations.map(&:id)
        Rails.logger.debug("조회된 대화 ID 목록: #{conversation_ids.inspect}")

        # nil 체크 추가
        if @conversations.nil?
          Rails.logger.error("대화 목록 조회 결과가 nil입니다.")
          @conversations = []
        end

        @conversations = @conversations.to_a

        # 대화 목록에 포함된 사용자 ID 로깅
        user_ids = @conversations.map do |conv|
          [ conv.user_a_id, conv.user_b_id ]
        end.flatten.uniq

        Rails.logger.debug("대화 목록에 포함된 사용자 ID: #{user_ids.inspect}")

        Rails.logger.debug("대화 목록 DB 조회 완료: #{@conversations.count}개 대화 찾음")

        Rails.logger.info("대화 목록 반환: #{@conversations.count}개")

        # 대화 목록 변환
        formatted_conversations = @conversations.map do |conversation|
          begin
            # 상대방 정보 구성
            other_user = (conversation.user_a_id == current_user.id) ? conversation.user_b : conversation.user_a

            # 메시지 정보 구성
            last_message = conversation.messages.max_by(&:created_at)

            # 마지막 메시지가 없는 경우 처리
            unless last_message
              Rails.logger.warn("대화 ID #{conversation.id}에 메시지가 없음")
              next nil
            end

            # 메시지 유형별 처리
            message_content = if last_message.message_type == "voice"
              "음성 메시지"
            elsif last_message.broadcast_id.present?
              # 브로드캐스트 참조 메시지 처리
              begin
                broadcast = last_message.broadcast
                broadcast ? "브로드캐스트: #{broadcast.content&.truncate(20) || '내용 없음'}" : "삭제된 브로드캐스트"
              rescue => e
                Rails.logger.error("브로드캐스트 참조 오류: #{e.message}")
                "브로드캐스트 메시지"
              end
            else
              last_message.content || "메시지"
            end

            {
              id: conversation.id,
              with_user: {
                id: other_user.id,
                nickname: other_user.nickname,
                gender: other_user.gender || "unspecified"
              },
              last_message: {
                id: last_message.id,
                content: message_content,
                created_at: last_message.created_at,
                message_type: last_message.message_type || "voice" # 기본값 제공
              },
              updated_at: conversation.updated_at,
              favorite: conversation.favorited_by?(current_user.id) # favorited_by? 메소드 사용
            }
          rescue => e
            Rails.logger.error("대화 정보 변환 중 오류: #{e.message}\n#{e.backtrace.join("\n")}")
            nil
          end
        end.compact

        render json: {
          success: true,
          conversations: formatted_conversations,
          request_id: request.request_id || SecureRandom.uuid
        }
      rescue => e
        Rails.logger.error("대화 목록 조회 오류: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: {
          success: false,
          error: "대화 목록을 불러오는 데 실패했습니다.",
          details: Rails.env.development? ? e.message : nil,
          request_id: request.request_id || SecureRandom.uuid
        }, status: :internal_server_error
      end
    end

    def show
      conversation = Conversation.find(params[:id])
      unless participant?(conversation)
        return render json: { error: "권한이 없습니다." }, status: :forbidden
      end

      # 대화방을 볼 때 사용자에게 가시성 설정
      if conversation.user_a_id == current_user.id && conversation.deleted_by_a
        conversation.update(deleted_by_a: false)
      elsif conversation.user_b_id == current_user.id && conversation.deleted_by_b
        conversation.update(deleted_by_b: false)
      end

      # 대화별 메시지 캐싱 (30초 유효)
      messages = Rails.cache.fetch("conversation-messages-#{conversation.id}", expires_in: 30.seconds) do
        conversation.messages.order(created_at: :asc).includes(:sender).to_a
      end

      # 상대방이 보낸 메시지를 읽음 처리
      unread_messages = messages.select { |m| m.sender_id != current_user.id && !m.read? }
      if unread_messages.any?
        Message.where(id: unread_messages.map(&:id)).update_all(read: true)
        # 캐시 무효화
        Rails.cache.delete("conversation-messages-#{conversation.id}")
        
        # 메시지를 다시 로드하여 최신 상태 반영
        messages = conversation.messages.order(created_at: :asc).includes(:sender).to_a
      end

      render json: {
        conversation: conversation,
        messages: messages.as_json(include: { sender: { only: [ :id, :nickname ] } })
      }
    end

    def destroy
      conversation = Conversation.find(params[:id])

      unless participant?(conversation)
        return render json: { error: "권한이 없습니다." }, status: :forbidden
      end

      # 실제 삭제하지 않고 현재 사용자에게만 보이지 않도록 설정
      if conversation.user_a_id == current_user.id
        conversation.update(deleted_by_a: true)
      elsif conversation.user_b_id == current_user.id
        conversation.update(deleted_by_b: true)
      end

      render json: { success: true, message: "대화방이 삭제되었습니다." }
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

      # 대화방이 삭제된 상태라면 가시성 복원 (응답 시 대화방 보이도록)
      if conversation.user_a_id == current_user.id && conversation.deleted_by_a
        conversation.update(deleted_by_a: false)
      elsif conversation.user_b_id == current_user.id && conversation.deleted_by_b
        conversation.update(deleted_by_b: false)
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
          data: message.as_json(include: { sender: { only: [ :id, :nickname ] } })
        }, status: :created
      else
        # 메시지 저장 실패
        render json: { error: message.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    private

    def participant?(conversation)
      [ conversation.user_a_id, conversation.user_b_id ].include?(current_user.id)
    end
  end
end
