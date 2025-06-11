# app/controllers/api/users_controller.rb
module Api
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :update, :destroy ]

    # GET /api/users/me
    def me
      Rails.logger.info("현재 로그인 사용자 조회: 사용자 ID #{current_user.id}")

      begin
        render json: {
          user: {
            id: current_user.id,
            phone_number: current_user.phone_number,
            nickname: current_user.nickname,
            gender: current_user.gender || "unspecified",
            push_enabled: current_user.push_enabled,
            broadcast_push_enabled: current_user.broadcast_push_enabled,
            message_push_enabled: current_user.message_push_enabled,
            push_token: current_user.push_token,
            wallet_balance: current_user.wallet_balance,
            unread_notification_count: current_user.unread_notification_count,
            created_at: current_user.created_at,
            updated_at: current_user.updated_at
          }
        }
      rescue => e
        Rails.logger.error("사용자 정보 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "사용자 정보를 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    # GET /api/users/notification_settings
    def notification_settings
      Rails.logger.info("사용자 알림 설정 조회: 사용자 ID #{current_user.id}")

      begin
        if current_user
          render json: {
            receive_new_letter: current_user.broadcast_push_enabled,
            letter_receive_alarm: current_user.message_push_enabled,
            push_enabled: current_user.push_enabled,
            broadcast_push_enabled: current_user.broadcast_push_enabled,
            message_push_enabled: current_user.message_push_enabled
          }
        else
          Rails.logger.warn("알림 설정 조회 시 사용자 인증 실패")
          render json: {
            error: "사용자를 찾을 수 없습니다. 토큰이 만료되었거나 유효하지 않습니다.",
            code: "invalid_token"
          }, status: :unauthorized
        end
      rescue => e
        Rails.logger.error("알림 설정 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "알림 설정을 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    # PATCH/PUT /api/users/notification_settings
    def update_notification_settings
      Rails.logger.info("사용자 알림 설정 업데이트: 사용자 ID #{current_user.id}")

      begin
        settings_params = params.permit(
          :receive_new_letter,
          :letter_receive_alarm,
          :push_enabled,
          :broadcast_push_enabled,
          :message_push_enabled
        )

        # 매개변수 매핑 (클라이언트 키 -> 서버 DB 컬럼)
        update_params = {}

        # 브로드캐스트 알림 설정
        if settings_params.key?(:receive_new_letter)
          update_params[:broadcast_push_enabled] = settings_params[:receive_new_letter]
        end

        # 메시지 알림 설정
        if settings_params.key?(:letter_receive_alarm)
          update_params[:message_push_enabled] = settings_params[:letter_receive_alarm]
        end

        # 전체 푸시 설정
        if settings_params.key?(:push_enabled)
          update_params[:push_enabled] = settings_params[:push_enabled]
        end

        # 개별 설정이 직접 전달된 경우 (이전 버전과의 호환성)
        if settings_params.key?(:broadcast_push_enabled)
          update_params[:broadcast_push_enabled] = settings_params[:broadcast_push_enabled]
        end

        if settings_params.key?(:message_push_enabled)
          update_params[:message_push_enabled] = settings_params[:message_push_enabled]
        end

        Rails.logger.info("알림 설정 업데이트 파라미터: #{update_params.inspect}")

        if current_user.update(update_params)
          Rails.logger.info("알림 설정 업데이트 성공: 사용자 ID #{current_user.id}")
          render json: {
            message: "알림 설정이 업데이트되었습니다.",
            receive_new_letter: current_user.broadcast_push_enabled,
            letter_receive_alarm: current_user.message_push_enabled,
            push_enabled: current_user.push_enabled,
            broadcast_push_enabled: current_user.broadcast_push_enabled,
            message_push_enabled: current_user.message_push_enabled
          }
        else
          Rails.logger.warn("알림 설정 업데이트 실패: #{current_user.errors.full_messages.join(', ')}")
          render json: { error: current_user.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error("알림 설정 업데이트 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "알림 설정을 업데이트하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    # GET /api/users/profile - 이전 버전 호환성을 위한 엔드포인트
    def profile
      Rails.logger.info("사용자 프로필 조회: #{current_user ? "사용자 ID #{current_user.id}" : "인증 실패"}")

      begin
        if current_user
          render json: {
            user: {
              id: current_user.id,
              phone_number: current_user.phone_number,
              nickname: current_user.nickname,
              gender: current_user.gender || "unspecified",
              push_enabled: current_user.push_enabled,
              broadcast_push_enabled: current_user.broadcast_push_enabled,
              message_push_enabled: current_user.message_push_enabled,
              push_token: current_user.push_token,
              wallet_balance: current_user.wallet_balance,
              unread_notification_count: current_user.unread_notification_count,
              created_at: current_user.created_at,
              updated_at: current_user.updated_at
            }
          }
        else
          Rails.logger.warn("프로필 조회 시 사용자 인증 실패")
          render json: {
            error: "사용자를 찾을 수 없습니다. 토큰이 만료되었거나 유효하지 않습니다.",
            code: "invalid_token"
          }, status: :unauthorized
        end
      rescue => e
        Rails.logger.error("프로필 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "사용자 정보를 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    # GET /api/users/:id
    def show
      begin
        # current_user를 사용하여 프로필 반환
        if current_user
          render json: {
            user: {
              id: current_user.id,
              phone_number: current_user.phone_number,
              nickname: current_user.nickname,
              gender: current_user.gender || "unspecified",
              push_enabled: current_user.push_enabled,
              broadcast_push_enabled: current_user.broadcast_push_enabled,
              message_push_enabled: current_user.message_push_enabled,
              created_at: current_user.created_at,
              updated_at: current_user.updated_at
            }
          }, status: :ok
        else
          render json: { error: "사용자를 찾을 수 없습니다." }, status: :not_found
        end
      rescue => e
        Rails.logger.error("특정 사용자 정보 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "사용자 정보를 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    # PATCH/PUT /api/users/me
    def update
      begin
        user_params = params.require(:user).permit(
          :nickname, :gender, :push_enabled, :broadcast_push_enabled,
          :message_push_enabled, :push_token
        )

        Rails.logger.info("사용자 정보 업데이트: 사용자 ID #{current_user.id}, 파라미터 #{user_params.inspect}")

        # 성별 유효성 검사
        if user_params[:gender].present?
          unless User.genders.keys.include?(user_params[:gender])
            return render json: { error: "유효하지 않은 성별입니다." }, status: :bad_request
          end
        end

        if current_user.update(user_params)
          Rails.logger.info("사용자 정보 업데이트 성공: #{current_user.id}")
          render json: {
            message: "사용자 정보가 업데이트되었습니다.",
            user: {
              id: current_user.id,
              phone_number: current_user.phone_number,
              nickname: current_user.nickname,
              gender: current_user.gender || "unspecified",
              push_enabled: current_user.push_enabled,
              broadcast_push_enabled: current_user.broadcast_push_enabled,
              message_push_enabled: current_user.message_push_enabled,
              push_token: current_user.push_token,
              wallet_balance: current_user.wallet_balance,
              unread_notification_count: current_user.unread_notification_count,
              created_at: current_user.created_at,
              updated_at: current_user.updated_at
            }
          }
        else
          Rails.logger.warn("사용자 정보 업데이트 실패: #{current_user.errors.full_messages.join(', ')}")
          render json: { error: current_user.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.warn("파라미터 누락: #{e.message}")
        render json: { error: "업데이트할 사용자 정보가 제공되지 않았습니다." }, status: :bad_request
      rescue => e
        Rails.logger.error("사용자 정보 업데이트 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "사용자 정보를 업데이트하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    # 비밀번호 변경
    def change_password
      begin
        password_params = params.require(:password).permit(:current_password, :new_password, :new_password_confirmation)

        Rails.logger.info("비밀번호 변경 요청: 사용자 ID #{current_user.id}")

        # 현재 비밀번호 확인
        unless current_user.authenticate(password_params[:current_password])
          Rails.logger.warn("현재 비밀번호 불일치: 사용자 ID #{current_user.id}")
          return render json: { error: "현재 비밀번호가 일치하지 않습니다." }, status: :unauthorized
        end

        # 새 비밀번호 유효성 검사
        if password_params[:new_password].blank? || password_params[:new_password].length < 6
          return render json: { error: "새 비밀번호는 최소 6자 이상이어야 합니다." }, status: :bad_request
        end

        # 새 비밀번호 확인
        if password_params[:new_password] != password_params[:new_password_confirmation]
          return render json: { error: "새 비밀번호와 비밀번호 확인이 일치하지 않습니다." }, status: :bad_request
        end

        # 비밀번호 업데이트
        current_user.password = password_params[:new_password]
        current_user.password_confirmation = password_params[:new_password_confirmation]

        if current_user.save
          Rails.logger.info("비밀번호 변경 성공: 사용자 ID #{current_user.id}")
          render json: { message: "비밀번호가 성공적으로 변경되었습니다." }
        else
          Rails.logger.warn("비밀번호 변경 실패: #{current_user.errors.full_messages.join(', ')}")
          render json: { error: current_user.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.warn("파라미터 누락: #{e.message}")
        render json: { error: "비밀번호 변경에 필요한 정보가 누락되었습니다." }, status: :bad_request
      rescue => e
        Rails.logger.error("비밀번호 변경 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "비밀번호 변경 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    # GET /api/users/random_nickname
    # 랜덤 닉네임을 생성하여 반환합니다.
    # 생성된 닉네임은 즉시 저장되지 않습니다.
    # 클라이언트는 이 닉네임을 사용자에게 제안하고,
    # 사용자가 확정하면 /api/users/change_nickname 엔드포인트를 호출하여 저장해야 합니다.
    def random_nickname
      begin
        nickname = generate_unique_random_nickname
        Rails.logger.info("랜덤 닉네임 생성: #{nickname}")
        render json: { nickname: nickname }, status: :ok
      rescue => e
        Rails.logger.error("랜덤 닉네임 생성 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "랜덤 닉네임을 생성하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    # POST /api/users/change_nickname
    # 사용자의 닉네임을 변경하고 저장합니다.
    # random_nickname으로 제안된 닉네임을 사용자가 확정했을 때 호출됩니다.
    def change_nickname
      begin
        new_nickname = params.require(:nickname)

        # 닉네임 유효성 검사 (예: 중복, 길이 등) - User 모델 콜백 또는 여기서 직접 수행
        if new_nickname.blank? || new_nickname.length < 2 || new_nickname.length > 15
          return render json: { error: "닉네임은 2자 이상 15자 이하이어야 합니다." }, status: :bad_request
        end

        # 중복 검사 (User 모델의 유효성 검사 활용 권장)
        if User.exists?(nickname: new_nickname) && current_user.nickname != new_nickname
          return render json: { error: "이미 사용 중인 닉네임입니다." }, status: :conflict
        end

        Rails.logger.info("닉네임 변경 시도: 사용자 ID #{current_user.id}, 새 닉네임: #{new_nickname}")

        if current_user.update(nickname: new_nickname)
          Rails.logger.info("닉네임 변경 성공: 사용자 ID #{current_user.id}")
          render json: { message: "닉네임이 성공적으로 변경되었습니다.", nickname: current_user.nickname }, status: :ok
        else
          Rails.logger.warn("닉네임 변경 실패: #{current_user.errors.full_messages.join(', ')}")
          render json: { error: current_user.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing
        render json: { error: "닉네임 파라미터가 필요합니다." }, status: :bad_request
      rescue => e
        Rails.logger.error("닉네임 변경 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "닉네임을 변경하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.warn("사용자를 찾을 수 없음: ID #{params[:id]}")
      render json: { error: "해당 사용자를 찾을 수 없습니다." }, status: :not_found
    end

    def generate_random_nickname_string
      # 형용사와 명사 리스트
      adjectives = [ "행복한", "즐거운", "멋진", "신나는", "귀여운", "활발한", "친절한", "사랑스러운", "따뜻한", "밝은",
                    "달콤한", "재미있는", "유쾌한", "상냥한", "다정한", "명랑한", "화사한", "산뜻한", "희망찬", "푸른" ]
      nouns = [ "고양이", "강아지", "토끼", "여우", "사자", "호랑이", "코끼리", "판다", "곰", "기린",
               "늑대", "양", "소", "말", "원숭이", "다람쥐", "펭귄", "코알라", "햄스터", "사슴" ]

      # 랜덤 선택
      adjective = adjectives.sample
      noun = nouns.sample
      number = rand(1..999)

      # 닉네임 조합
      "#{adjective}#{noun}#{number}"
    end
  end
end
