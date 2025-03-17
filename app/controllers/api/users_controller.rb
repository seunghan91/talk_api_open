# app/controllers/api/users_controller.rb
module Api
  class UsersController < BaseController
    # before_action :authorize_request, except: [:some_public_method]
    
    def update_push_token
      # 클라이언트에서 { token: "ExponentPushToken[...]" } 형태로 POST 요청
      push_token = params[:token]
      if push_token.blank?
        return render json: { error: "No push token provided" }, status: :bad_request
      end

      # 현재 로그인된 유저(@current_user) 기준 (JWT 인증)
      @current_user.expo_push_token = push_token
      if @current_user.save
        render json: { message: "푸시 토큰이 저장되었습니다." }, status: :ok
      else
        render json: { errors: @current_user.errors.full_messages }, status: :unprocessable_entity
      end
    end
  
    # 현재 사용자 정보 조회
    def me
      render json: {
        user: {
          id: current_user.id,
          phone_number: current_user.phone_number,
          nickname: current_user.nickname,
          gender: current_user.gender,
          verified: current_user.verified
        }
      }
    end

    # 닉네임 변경 API
    def change_nickname
      new_nickname = params[:nickname]
      
      return render json: { error: "새 닉네임은 필수입니다." }, status: :bad_request if new_nickname.blank?
      
      # TODO: 추후 결제 시스템이 구현되면 결제 확인 로직을 여기에 추가
      # if !current_user.has_paid_for_nickname_change?
      #   return render json: { error: "닉네임 변경 권한이 없습니다. 결제가 필요합니다." }, status: :payment_required
      # end
      
      # 테스트용 코드: 결제 없이 닉네임 변경 허용 (나중에 수정 필요)
      if current_user.update(nickname: new_nickname)
        render json: {
          message: "닉네임이 변경되었습니다.",
          user: {
            id: current_user.id,
            nickname: current_user.nickname
          }
        }
      else
        render json: { error: current_user.errors.full_messages }, status: :unprocessable_entity
      end
    end
    
    # 랜덤 닉네임 생성 API
    def generate_random_nickname
      random_nickname = NicknameGenerator.generate_unique
      
      render json: {
        nickname: random_nickname
      }
    end
    
    # 사용자 프로필 업데이트 API
    def update_profile
      # 허용된 파라미터만 추출
      profile_params = params.permit(:nickname, :gender)
      
      # 로그 추가
      Rails.logger.info("프로필 업데이트 요청: #{profile_params.inspect}")
      Rails.logger.info("요청된 성별 값: #{profile_params[:gender]}, 타입: #{profile_params[:gender].class}")
      
      # 닉네임이 비어있으면 랜덤 생성
      if profile_params[:nickname].blank?
        profile_params[:nickname] = NicknameGenerator.generate_unique
      end
      
      # 성별이 유효한지 확인 (male, female, unknown)
      if profile_params[:gender].present?
        Rails.logger.info("유효한 성별 값 목록: #{User.genders.keys}")
        
        unless User.genders.keys.include?(profile_params[:gender])
          Rails.logger.warn("유효하지 않은 성별 값: #{profile_params[:gender]}")
          return render json: { error: "유효하지 않은 성별입니다. 'unknown', 'male', 'female' 중 하나여야 합니다." }, status: :bad_request
        end
      end
      
      if current_user.update(profile_params)
        # 업데이트 성공 로그
        Rails.logger.info("프로필 업데이트 성공: User ID #{current_user.id}, 닉네임: #{current_user.nickname}, 성별: #{current_user.gender}")
        
        render json: {
          success: true,
          message: "프로필이 업데이트되었습니다.",
          user: {
            id: current_user.id,
            phone_number: current_user.phone_number,
            nickname: current_user.nickname,
            gender: current_user.gender,
            verified: current_user.verified
          }
        }
      else
        # 업데이트 실패 로그
        Rails.logger.error("프로필 업데이트 실패: #{current_user.errors.full_messages}")
        
        render json: { error: current_user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # 알림 설정 조회
    def notification_settings
      # 현재 유저 @current_user (BaseController에서 authorize_request로 세팅)
      render json: {
        receive_new_letter: @current_user.receive_new_letter || true,
        letter_receive_alarm: @current_user.letter_receive_alarm || true
      }, status: :ok
    end

    # 알림 설정 갱신
    def update_notification_settings
      # params[:receive_new_letter], params[:letter_receive_alarm] 를 받아서 업데이트
      @current_user.receive_new_letter = params[:receive_new_letter]
      @current_user.letter_receive_alarm = params[:letter_receive_alarm]

      if @current_user.save
        render json: { message: '알림 설정이 업데이트되었습니다.' }, status: :ok
      else
        render json: { error: '업데이트 실패', details: @current_user.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end