module Api
  class BroadcastsController < BaseController
    before_action :authorize_request
    # 인증 요청 엔드포인트는 인증 없이 접근 가능하도록 설정
    # request_code와 verify_code 액션이 없으므로 제거
    # skip_before_action :authorize_request, only: [:request_code, :verify_code]

    def index
      # 캐싱 적용 (5분 유효)
      @broadcasts = Rails.cache.fetch("broadcasts-recent", expires_in: 5.minutes) do
        Broadcast.where("expired_at > ?", Time.current)
                 .includes(:user) # N+1 쿼리 문제 해결
                 .order(created_at: :desc)
                 .limit(20)
                 .to_a
      end
      
      render json: @broadcasts, include: { user: { only: [:id, :nickname, :gender] } }
    end

    def create
      # 브로드캐스트 생성 요청 로깅
      Rails.logger.info "Broadcast creation request from user: #{current_user.id}, #{current_user.nickname}"
      
      # 음성 파일 확인 - 파라미터 이름을 'broadcast[voice_file]'에서 'voice_file'로 변경
      voice_file = params[:voice_file]
      Rails.logger.info "Voice file received: #{voice_file.present?}"
      
      if voice_file.blank?
        Rails.logger.warn "음성 파일이 없습니다: 사용자 ID #{current_user.id}"
        return render json: { error: "음성 파일이 필요합니다." }, status: :bad_request
      end
      
      # 음성 파일 로깅
      if voice_file.present?
        Rails.logger.info "음성 파일 첨부됨: #{voice_file.original_filename}"
        Rails.logger.info "음성 파일 타입: #{voice_file.content_type}"
        Rails.logger.info "음성 파일 크기: #{voice_file.size} 바이트"
      end
      
      # 브로드캐스트 생성 로직 - 개발 환경에서는 하드코딩된 응답 반환
      if Rails.env.development?
        # 수신자 목록에서 현재 사용자 제외
        all_test_recipients = [
          { id: 1, nickname: "김철수" },
          { id: 2, nickname: "이영희" },
          { id: 3, nickname: "박지민" },
          { id: 4, nickname: "최수진" },
          { id: 5, nickname: "정민준" }
        ]
        
        # 현재 사용자 ID를 기반으로 수신자 목록에서 제외
        filtered_recipients = all_test_recipients.reject { |recipient| recipient[:id] == current_user.id }
        
        # 현재 시간 및 만료 시간 설정 (6일 후)
        current_time = Time.now
        expiry_time = current_time + 6.days
        
        render json: {
          message: "방송이 성공적으로 생성되었습니다.",
          broadcast: {
            id: SecureRandom.uuid,
            created_at: current_time,
            expired_at: expiry_time,
            user: {
              id: current_user.id,
              nickname: current_user.nickname
            }
          },
          recipient_count: filtered_recipients.length,
          recipients: filtered_recipients
        }, status: :created
      else
        # 실제 구현: 데이터베이스에 저장하고 파일 업로드
        @broadcast = current_user.broadcasts.new(
          active: true,
          expired_at: Time.current + 6.days
        )
        
        begin
          # 음성 파일 첨부
          @broadcast.voice_file.attach(voice_file)
          
          # 첨부 확인
          if @broadcast.voice_file.attached?
            Rails.logger.info "음성 파일 첨부 성공"
          else
            Rails.logger.error "음성 파일 첨부 실패"
            return render json: { error: "음성 파일 첨부에 실패했습니다." }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "음성 파일 첨부 중 오류: #{e.message}"
          return render json: { error: "음성 파일 처리 중 오류가 발생했습니다: #{e.message}" }, status: :unprocessable_entity
        end
        
        if @broadcast.save
          # 캐시 무효화
          Rails.cache.delete("broadcasts-recent")
          
          # 수신자 목록 생성 (실제 구현에서는 알고리즘에 따라 결정)
          recipient_count = 5 # 임의의 수
          recipients = User.where.not(id: current_user.id).limit(recipient_count)
          recipient_data = recipients.map { |r| { id: r.id, nickname: r.nickname } }
          
          render json: {
            message: "방송이 성공적으로 생성되었습니다.",
            broadcast: {
              id: @broadcast.id,
              created_at: @broadcast.created_at,
              expired_at: @broadcast.expired_at,
              user: {
                id: current_user.id,
                nickname: current_user.nickname
              }
            },
            recipient_count: recipient_data.length,
            recipients: recipient_data
          }, status: :created
        else
          Rails.logger.error "방송 생성 실패: #{@broadcast.errors.full_messages}"
          render json: { errors: @broadcast.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
    
    def show
      @broadcast = Broadcast.find(params[:id])
      render json: @broadcast
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
        
        # 대화 찾기 또는 생성
        conversation = Conversation.find_or_create_by(
          user_a_id: current_user.id,
          user_b_id: broadcast.user_id
        )
        
        Rails.logger.info("대화 ID: #{conversation.id}, 상대방 ID: #{broadcast.user_id}")
        
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
          PushNotificationWorker.perform_async('broadcast_reply', broadcast.id, current_user.id)
          
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
