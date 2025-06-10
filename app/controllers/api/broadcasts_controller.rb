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
                                     .where('broadcasts.created_at > ?', 6.days.ago) # 6일 이내 브로드캐스트만
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
      begin
        Rails.logger.info "Broadcast creation request from user: #{current_user.id}, #{current_user.nickname}"

        # 파라미터 유효성 검사
        broadcast_params = params.require(:broadcast).permit(:audio, :text, :recipient_count)

        # 음성 파일이 있는지 확인
        unless broadcast_params[:audio].present?
          Rails.logger.warn "음성 파일이 없습니다: 사용자 ID #{current_user.id}"
          return render json: { error: "음성 파일이 필요합니다." }, status: :bad_request
        end

        # 텍스트 메시지가 있는지 확인 (선택 사항)
        broadcast_text = broadcast_params[:text].presence || "새로운 음성 메시지"

        # 수신자 수 설정 (기본값: 5)
        recipient_count = (broadcast_params[:recipient_count] || 5).to_i
        recipient_count = 5 if recipient_count <= 0 || recipient_count > 10

        # 테스트 계정 처리 - 실제 환경에서는 제거
        is_test_account = current_user.phone_number.match?(/^010\d{8}$/) &&
                         current_user.phone_number.gsub(/\D/, "").match?(/^010(1|2|3|4|5){2}+\1{6}$/)

        if is_test_account
          Rails.logger.info "테스트 계정 방송 처리: #{current_user.phone_number}"
          # 테스트 계정은 다른 테스트 계정에만 방송
          all_test_recipients = [
            { id: 1, phone_number: "01011111111", nickname: "김철수", gender: "male" },
            { id: 2, phone_number: "01022222222", nickname: "이영희", gender: "female" },
            { id: 3, phone_number: "01033333333", nickname: "박지민", gender: "male" },
            { id: 4, phone_number: "01044444444", nickname: "최수진", gender: "female" },
            { id: 5, phone_number: "01055555555", nickname: "정민준", gender: "male" }
          ]

          # 현재 사용자를 제외
          filtered_recipients = all_test_recipients.reject { |recipient| recipient[:id] == current_user.id }

          # 수신자 수만큼 선택
          recipients = filtered_recipients.sample(recipient_count)

          # 방송 생성 및 저장
          # 여기서는 테스트 데이터만 반환하고 실제 저장은 하지 않음
          render json: {
            message: "방송이 성공적으로 전송되었습니다.",
            broadcast: {
              id: SecureRandom.uuid,
              audio_url: "https://example.com/test_audio.mp3",
              text: broadcast_text,
              sender: {
                id: current_user.id,
                nickname: current_user.nickname
              },
              recipients: recipients,
              created_at: Time.current,
              is_test: true
            }
          }, status: :created
          return
        end

        # 실제 방송 생성 로직
        @broadcast = current_user.broadcasts.new(
          text: broadcast_text,
          audio: broadcast_params[:audio]
        )

        # DEBUG: 로그 추가
        Rails.logger.info("현재 사용자: ID #{current_user.id}, #{current_user.nickname}")
        Rails.logger.info("모든 사용자: #{User.all.map{|u| "ID #{u.id}: #{u.nickname}"}.join(', ')}")
        Rails.logger.info("현재 모든 대화: #{Conversation.all.map{|c| "ID #{c.id}: #{c.user_a_id} <-> #{c.user_b_id}"}.join(', ')}")
        
        # 수신자 선택 로직 - 시스템의 모든 사용자를 선택 (무작위 선택 X)
        recipients = User.where.not(id: current_user.id)
        Rails.logger.info("선택된 수신자: #{recipients.map{|r| "ID #{r.id}: #{r.nickname}"}.join(', ')}")

        # 비동기 작업 실행 (Sidekiq)
        broadcast_id = nil

        if @broadcast.save
          broadcast_id = @broadcast.id
          # 비동기 작업을 통해 푸시 알림 전송
          BroadcastWorker.perform_async(broadcast_id, recipient_count)

          render json: {
            message: "방송이 성공적으로 전송되었습니다.",
            broadcast: {
              id: @broadcast.id,
              audio_url: @broadcast.audio.url,
              text: @broadcast.text,
              sender: {
                id: current_user.id,
                nickname: current_user.nickname
              },
              created_at: @broadcast.created_at
            }
          }, status: :created
        else
          Rails.logger.warn("방송 생성 실패: #{@broadcast.errors.full_messages.join(', ')}")
          render json: { error: @broadcast.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.warn("파라미터 누락: #{e.message}")
        render json: { error: "필수 파라미터가 누락되었습니다." }, status: :bad_request
      rescue Redis::CannotConnectError, RedisClient::CannotConnectError => e
        Rails.logger.error("Redis 연결 실패: #{e.message}")
        render json: {
          error: "방송 서비스에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.",
          details: "Redis 연결 실패: #{e.message}"
        }, status: :service_unavailable
      rescue Sidekiq::JobRetry::Skip => e
        Rails.logger.error("Sidekiq 작업 건너뛰기: #{e.message}")
        render json: {
          error: "백그라운드 작업을 처리할 수 없습니다. 잠시 후 다시 시도해주세요.",
          details: "Sidekiq 오류: #{e.message}"
        }, status: :service_unavailable
      rescue => e
        Rails.logger.error("방송 생성 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "방송을 전송하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
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
        
        if recipient.update(status: 'read')
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

        # 대화방 가시성 보장을 위한 로그 추가
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
