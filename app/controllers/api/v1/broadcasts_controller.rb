module Api
  module V1
    class BroadcastsController < Api::V1::BaseController
      before_action :authorize_request
      before_action :ensure_user_active
      # 인증 요청 엔드포인트는 인증 없이 접근 가능하도록 설정
      # request_code와 verify_code 액션이 없으므로 제거
      # skip_before_action :authorize_request, only: [:request_code, :verify_code]

      # 예제 브로드캐스트 API 추가
      def example_broadcast
        begin
          # 샘플 오디오 파일 URL 생성
          base_url = ENV.fetch("RENDER_EXTERNAL_URL", "http://#{request.host_with_port}")
          sample_audio_url = "#{base_url}/audio_samples/sample_audio.wav"
          
          # 샘플 브로드캐스트 응답 생성
          render json: {
            example_broadcast: {
              id: 999,
              text: "이것은 샘플 브로드캐스트입니다.",
              audio_url: sample_audio_url,
              created_at: Time.current,
              sender: {
                id: current_user.id,
                nickname: current_user.nickname
              }
            },
            message: "이 브로드캐스트는 테스트용 예제입니다. 실제 데이터베이스에 저장되지 않습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }
        rescue => e
          Rails.logger.error("예제 브로드캐스트 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { 
            error: "예제 브로드캐스트를 조회하는 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      def index
        begin
          # 현재 사용자가 보낸 방송 목록 + 수신한 방송 목록
          # N+1 쿼리 방지를 위해 includes 사용
          @broadcasts = current_user.broadcasts
                                   .includes(:user)  # 발신자 정보 미리 로드
                                   .with_attached_audio  # 음성 파일 미리 로드
                                   .order(created_at: :desc)
                                   .limit(50)

          render json: {
            broadcasts: @broadcasts.map { |broadcast| broadcast_response(broadcast) },
            request_id: request.request_id || SecureRandom.uuid
          }
        rescue => e
          Rails.logger.error("방송 목록 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { 
            error: "방송 목록을 조회하는 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      def create
        begin
          Rails.logger.info "방송 생성 요청: 사용자 ID #{current_user.id}, 닉네임 #{current_user.nickname}"

          # 파라미터 유효성 검사
          broadcast_params = params.require(:broadcast).permit(:audio, :text, :recipient_count)

          # 음성 파일이 있는지 확인
          unless broadcast_params[:audio].present?
            Rails.logger.warn "음성 파일이 없습니다: 사용자 ID #{current_user.id}"
            return render json: { 
              error: "음성 파일이 필요합니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :bad_request
          end

          # 텍스트 메시지가 있는지 확인 (선택 사항)
          broadcast_text = broadcast_params[:text].presence || "새로운 음성 메시지"

          # 수신자 수 설정 (기본값: 5)
          recipient_count = (broadcast_params[:recipient_count] || 5).to_i
          recipient_count = 5 if recipient_count <= 0 || recipient_count > 10

          # 테스트 계정 처리
          if is_test_account?
            return handle_test_account_broadcast(broadcast_text, recipient_count)
          end

          # 실제 방송 생성 로직
          @broadcast = current_user.broadcasts.new(
            text: broadcast_text
          )
          
          # 음성 파일 첨부
          @broadcast.audio.attach(broadcast_params[:audio])

          # 트랜잭션 처리
          Broadcast.transaction do
            if @broadcast.save
              # 비동기 작업을 통해 수신자 선택 및 대화 생성
              BroadcastWorker.perform_async(@broadcast.id, recipient_count)

              render json: {
                message: "방송이 성공적으로 전송되었습니다.",
                broadcast: {
                  id: @broadcast.id,
                  audio_url: @broadcast.audio_url,
                  text: @broadcast.text,
                  sender: {
                    id: current_user.id,
                    nickname: current_user.nickname
                  },
                  created_at: @broadcast.created_at
                },
                request_id: request.request_id || SecureRandom.uuid
              }, status: :created
            else
              Rails.logger.warn("방송 생성 실패: #{@broadcast.errors.full_messages.join(', ')}")
              render json: { 
                error: @broadcast.errors.full_messages.join(", "),
                request_id: request.request_id || SecureRandom.uuid
              }, status: :unprocessable_entity
            end
          end
        rescue ActionController::ParameterMissing => e
          Rails.logger.warn("파라미터 누락: #{e.message}")
          render json: { 
            error: "필수 파라미터가 누락되었습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :bad_request
        rescue Redis::CannotConnectError, RedisClient::CannotConnectError => e
          Rails.logger.error("Redis 연결 실패: #{e.message}")
          render json: {
            error: "방송 서비스에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.",
            details: "Redis 연결 실패: #{e.message}",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :service_unavailable
        rescue Sidekiq::JobRetry::Skip => e
          Rails.logger.error("Sidekiq 작업 건너뛰기: #{e.message}")
          render json: {
            error: "백그라운드 작업을 처리할 수 없습니다. 잠시 후 다시 시도해주세요.",
            details: "Sidekiq 오류: #{e.message}",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :service_unavailable
        rescue => e
          Rails.logger.error("방송 생성 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { 
            error: "방송을 전송하는 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      def show
        begin
          @broadcast = Broadcast.includes(:user)
                               .with_attached_audio
                               .find_by(id: params[:id])
                               
          unless @broadcast
            return render json: { 
              error: "방송을 찾을 수 없습니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :not_found
          end
          
          # 권한 검사: 자신의 방송이거나 수신한 방송인지 확인
          unless @broadcast.user_id == current_user.id || is_recipient?(@broadcast)
            return render json: { 
              error: "이 방송에 접근할 권한이 없습니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :forbidden
          end
          
          render json: {
            broadcast: broadcast_detail_response(@broadcast),
            request_id: request.request_id || SecureRandom.uuid
          }
        rescue => e
          Rails.logger.error("방송 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { 
            error: "방송을 조회하는 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      def reply
        # 로깅 추가
        Rails.logger.info("방송 답장 요청: 사용자 ID #{current_user.id}, 방송 ID #{params[:id]}")

        begin
          broadcast = Broadcast.find_by(id: params[:id])
          
          unless broadcast
            Rails.logger.error("방송을 찾을 수 없음: ID #{params[:id]}")
            return render json: { 
              error: "방송을 찾을 수 없습니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :not_found
          end
          
          # 권한 검사: 수신한 방송인지 확인
          unless is_recipient?(broadcast)
            return render json: { 
              error: "이 방송에 답장할 권한이 없습니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :forbidden
          end

          # 음성 파일 첨부 확인
          unless params[:voice_file].present?
            Rails.logger.warn("음성 파일 없음: 답장 실패")
            return render json: { 
              error: "음성 파일이 필요합니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :bad_request
          end

          # 음성 파일 로깅
          Rails.logger.info("음성 파일 첨부됨: #{params[:voice_file].original_filename}")
          Rails.logger.info("음성 파일 타입: #{params[:voice_file].content_type}")
          Rails.logger.info("음성 파일 크기: #{params[:voice_file].size} 바이트")

          # 트랜잭션 처리로 일관성 보장
          ActiveRecord::Base.transaction do
            # 대화 찾기 또는 생성
            conversation = Conversation.find_or_create_conversation(
              current_user.id, broadcast.user_id
            )

            Rails.logger.info("대화 ID: #{conversation.id}, 상대방 ID: #{broadcast.user_id}")

            # 메시지 생성
            message = conversation.messages.new(
              sender_id: current_user.id,
              message_type: "voice"
            )

            # 음성 파일 첨부
            message.voice_file.attach(params[:voice_file])

            # 첨부 확인
            if !message.voice_file.attached?
              Rails.logger.error("메시지 음성 파일 첨부 실패")
              raise ActiveRecord::Rollback, "음성 파일 첨부에 실패했습니다."
            end

            # 메시지 저장
            unless message.save
              Rails.logger.error("답장 실패: #{message.errors.full_messages.join(', ')}")
              raise ActiveRecord::Rollback, message.errors.full_messages.join(", ")
            end

            # 브로드캐스트 수신자 상태 업데이트 (답장 상태로)
            broadcast_recipient = BroadcastRecipient.find_by(
              broadcast_id: broadcast.id,
              user_id: current_user.id
            )
            
            if broadcast_recipient
              broadcast_recipient.update(status: :replied)
            end

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
              },
              request_id: request.request_id || SecureRandom.uuid
            }, status: :ok
          end
        rescue ActiveRecord::RecordNotFound
          Rails.logger.error("방송을 찾을 수 없음: ID #{params[:id]}")
          render json: { 
            error: "방송을 찾을 수 없습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :not_found
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error("유효성 검사 실패: #{e.message}")
          render json: { 
            error: "답장 처리 중 유효성 검사에 실패했습니다: #{e.message}",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :unprocessable_entity
        rescue => e
          Rails.logger.error("답장 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { 
            error: "답장 처리 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      private

      # 사용자가 활성 상태인지 확인
      def ensure_user_active
        unless current_user.status_active?
          Rails.logger.warn("비활성 사용자의 방송 접근 시도: 사용자 ID #{current_user.id}, 상태 #{current_user.status}")
          render json: { 
            error: "현재 계정 상태로는 이 기능을 사용할 수 없습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :forbidden
          return false
        end
        true
      end
      
      # 테스트 계정 여부 확인
      def is_test_account?
        current_user.phone_number.match?(/^010\d{8}$/) &&
        current_user.phone_number.gsub(/\D/, "").match?(/^010(1|2|3|4|5){2}+\1{6}$/)
      end
      
      # 테스트 계정 방송 처리
      def handle_test_account_broadcast(broadcast_text, recipient_count)
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
          },
          request_id: request.request_id || SecureRandom.uuid
        }, status: :created
      end
      
      # 현재 사용자가 방송의 수신자인지 확인
      def is_recipient?(broadcast)
        BroadcastRecipient.exists?(broadcast_id: broadcast.id, user_id: current_user.id)
      end

      # 방송 목록 응답 포맷
      def broadcast_response(broadcast)
        # 오디오 URL 유효 기간 설정 (환경 변수에서 가져오거나 기본값 7일 사용)
        audio_url_expiry = ENV.fetch('AUDIO_URL_EXPIRY_DAYS', '7').to_i.days
        
        # 로그에 현재 설정된 만료 시간 기록 (디버깅용)
        Rails.logger.debug("오디오 URL 만료 시간 설정: #{audio_url_expiry / 1.day}일")
        
        {
          id: broadcast.id,
          text: broadcast.text,
          # 서명된 URL 생성 - 콘텐츠 자체 만료 시간과 일관되게 설정
          audio_url: broadcast.audio.attached? ? rails_blob_url(broadcast.audio, disposition: "attachment", expires_in: audio_url_expiry) : nil,
          sender: {
            id: broadcast.user_id,
            nickname: broadcast.user.nickname
          },
          created_at: broadcast.created_at
        }
      end
      
      # 방송 상세 응답 포맷
      def broadcast_detail_response(broadcast)
        response = broadcast_response(broadcast)
        
        # 수신자 목록 추가 (본인이 발신자인 경우에만)
        if broadcast.user_id == current_user.id
          recipients = BroadcastRecipient.includes(:user)
                                        .where(broadcast_id: broadcast.id)
                                        .map do |br|
            {
              id: br.user_id,
              nickname: br.user.nickname,
              status: br.status
            }
          end
          
          response[:recipients] = recipients
        end
        
        # 본인이 수신자인 경우 상태 추가
        if broadcast.user_id != current_user.id
          recipient = BroadcastRecipient.find_by(broadcast_id: broadcast.id, user_id: current_user.id)
          response[:status] = recipient&.status
        end
        
        response
      end
    end
  end
end
