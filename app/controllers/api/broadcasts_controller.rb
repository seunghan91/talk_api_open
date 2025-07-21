module Api
  class BroadcastsController < BaseController
    before_action :authorize_request
    # 인증 요청 엔드포인트는 인증 없이 접근 가능하도록 설정
    # request_code와 verify_code 액션이 없으므로 제거
    # skip_before_action :authorize_request, only: [:request_code, :verify_code]

    def index
      begin
        # 현재 사용자가 보낸 방송 목록만 조회
        @broadcasts = current_user.broadcasts.order(created_at: :desc).limit(50)

        render json: {
          broadcasts: @broadcasts.map { |broadcast| broadcast_response(broadcast) }
        }
      rescue => e
        Rails.logger.error("방송 목록 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "방송 목록을 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    # 수신한 브로드캐스트 목록 조회
    def received
      begin
        # 현재 사용자가 수신한 방송 목록 조회
        received_broadcasts = Broadcast.joins(:broadcast_recipients)
                                     .where(broadcast_recipients: { recipient_id: current_user.id })
                                     .where("broadcasts.created_at > ?", 6.days.ago) # 6일 이내 브로드캐스트만
                                     .order(created_at: :desc)
                                     .limit(50)

        render json: {
          broadcasts: received_broadcasts.map do |broadcast|
            recipient = broadcast.broadcast_recipients.find_by(recipient_id: current_user.id)
            broadcast_response(broadcast).merge(
              status: recipient.status,
              received_at: recipient.created_at
            )
          end
        }
      rescue => e
        Rails.logger.error("수신 방송 목록 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "수신 방송 목록을 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    def create
      # SOLID 원칙에 따라 리팩토링 - 서비스 객체 사용
      result = Broadcasts::CreateService.new(
        user: current_user,
        audio: broadcast_params[:audio],
        text: broadcast_params[:text],
        recipient_count: broadcast_params[:recipient_count]
      ).call

      if result.success?
        render json: {
          message: "방송이 성공적으로 전송되었습니다.",
          broadcast: broadcast_response(result.broadcast)
        }, status: :created
      else
        Rails.logger.warn("방송 생성 실패: #{result.error}")
        render json: { error: result.error }, status: :unprocessable_entity
      end
    rescue ActionController::ParameterMissing => e
      Rails.logger.warn("파라미터 누락: #{e.message}")
      render json: { error: "필수 파라미터가 누락되었습니다." }, status: :bad_request
    rescue => e
      Rails.logger.error("방송 생성 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
      render json: { error: "방송을 전송하는 중 오류가 발생했습니다." }, status: :internal_server_error
    end

    private

    def broadcast_params
      params.require(:broadcast).permit(:audio, :text, :recipient_count)
    end

    def show
      @broadcast = Broadcast.find(params[:id])
      render json: @broadcast
    end

    # 브로드캐스트를 읽음으로 표시
    def mark_as_read
      begin
        broadcast = Broadcast.find(params[:id])
        recipient = broadcast.broadcast_recipients.find_by(recipient_id: current_user.id)

        unless recipient
          return render json: { error: "이 브로드캐스트의 수신자가 아닙니다." }, status: :forbidden
        end

        if recipient.update(status: "read")
          render json: { message: "브로드캐스트가 읽음으로 표시되었습니다." }, status: :ok
        else
          render json: { error: "상태 업데이트에 실패했습니다." }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "브로드캐스트를 찾을 수 없습니다." }, status: :not_found
      rescue => e
        Rails.logger.error("브로드캐스트 읽음 처리 중 오류: #{e.message}")
        render json: { error: "읽음 처리 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    def reply
      # 로깅 추가
      Rails.logger.info("방송 답장 요청: 사용자 ID #{current_user.id}, 방송 ID #{params[:id]}")

      begin
        broadcast = Broadcast.find(params[:id])

        # 브로드캐스트 수신자 확인 및 상태 업데이트
        broadcast_recipient = broadcast.broadcast_recipients.find_by(recipient_id: current_user.id)
        if broadcast_recipient
          broadcast_recipient.update(status: 'replied')
          Rails.logger.info("브로드캐스트 수신자 상태 업데이트: replied")
        end

        # 음성 파일 첨부 확인
        unless params[:voice_file].present?
          Rails.logger.warn("음성 파일 없음: 답장 실패")
          return render json: { error: "음성 파일이 필요합니다." }, status: :bad_request
        end

        # 음성 파일 로깅
        Rails.logger.info("음성 파일 첨부됨: #{params[:voice_file].original_filename}")
        Rails.logger.info("음성 파일 타입: #{params[:voice_file].content_type}")
        Rails.logger.info("음성 파일 크기: #{params[:voice_file].size} 바이트")

        # 대화 찾기 또는 생성 - 수정됨
        # 기존 find_or_create_by 대신 find_or_create_conversation 사용
        conversation = Conversation.find_or_create_conversation(
          current_user.id,
          broadcast.user_id,
          broadcast
        )

        # 대화방 가시성 보장 - 응답하는 사용자에게도 대화방이 보이도록 설정
        conversation.show_to!(current_user.id)
        conversation.show_to!(broadcast.user_id)
        
        Rails.logger.info("대화방 설정: ID #{conversation.id}, user_a_id: #{conversation.user_a_id}, user_b_id: #{conversation.user_b_id}")
        Rails.logger.info("삭제 상태: deleted_by_a: #{conversation.deleted_by_a}, deleted_by_b: #{conversation.deleted_by_b}")

        # 메시지 생성
        message = conversation.messages.new(sender_id: current_user.id)

        begin
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
          # 성공 로깅
          Rails.logger.info("답장 성공: 메시지 ID #{message.id}")

          # 푸시 알림 전송
          PushNotificationWorker.perform_async("broadcast_reply", broadcast.id, current_user.id)

          # 응답 개선
          render json: {
            message: "답장이 성공적으로 전송되었습니다.",
            conversation: {
              id: conversation.id,
              with_user: {
                id: broadcast.user_id,
                nickname: broadcast.user.nickname
              }
            }
          }, status: :ok
        else
          # 실패 로깅
          Rails.logger.error("답장 실패: #{message.errors.full_messages}")
          render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        Rails.logger.error("방송을 찾을 수 없음: ID #{params[:id]}")
        render json: { error: "방송을 찾을 수 없습니다." }, status: :not_found
      rescue => e
        Rails.logger.error("답장 중 오류 발생: #{e.message}")
        render json: { error: "답장 처리 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end
  end
end
