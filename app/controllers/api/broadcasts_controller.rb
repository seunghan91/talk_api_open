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
                 .where(active: true)
                 .includes(:user) # N+1 쿼리 문제 해결
                 .order(created_at: :desc)
                 .limit(20)
                 .to_a
      end
      
      render json: @broadcasts, include: { user: { only: [:id, :nickname, :gender] } }
    end

    def create
      # 로깅 추가
      Rails.logger.info("방송 생성 요청: 사용자 ID #{current_user.id}, 닉네임: #{current_user.nickname}")
      
      # 기본 만료 시간 설정 (24시간)
      @broadcast = current_user.broadcasts.new(
        active: true,
        expired_at: Time.current + 24.hours
      )
      
      # 음성 파일 첨부 확인 및 로깅
      if params[:voice_file].present?
        begin
          Rails.logger.info("음성 파일 첨부됨: #{params[:voice_file].original_filename}")
          Rails.logger.info("음성 파일 타입: #{params[:voice_file].content_type}")
          Rails.logger.info("음성 파일 크기: #{params[:voice_file].size} 바이트")
          
          # 음성 파일 직접 첨부 (무음 구간 트리밍 없이)
          @broadcast.voice_file.attach(params[:voice_file])
          
          # 첨부 확인
          if @broadcast.voice_file.attached?
            Rails.logger.info("음성 파일 첨부 성공")
          else
            Rails.logger.error("음성 파일 첨부 실패")
            return render json: { error: "음성 파일 첨부에 실패했습니다." }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("음성 파일 첨부 중 오류: #{e.message}")
          return render json: { error: "음성 파일 처리 중 오류가 발생했습니다: #{e.message}" }, status: :unprocessable_entity
        end
      else
        Rails.logger.warn("음성 파일 없음: 방송 생성 실패")
        return render json: { error: "음성 파일이 필요합니다." }, status: :bad_request
      end
      
      if @broadcast.save
        # 캐시 무효화
        Rails.cache.delete("broadcasts-recent")
        
        # 성공 로깅
        Rails.logger.info("방송 생성 성공: ID #{@broadcast.id}")
        
        # 응답 개선
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
          }
        }, status: :created
      else
        # 실패 로깅
        Rails.logger.error("방송 생성 실패: #{@broadcast.errors.full_messages}")
        
        render json: { errors: @broadcast.errors.full_messages }, status: :unprocessable_entity
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
