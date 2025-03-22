# app/controllers/api/users_controller.rb
module Api
  class UsersController < BaseController
    before_action :set_user, only: [:show, :update, :destroy]
    
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
    
    # GET /api/users/:id
    def show
      begin
        render json: {
          user: {
            id: @user.id,
            nickname: @user.nickname,
            gender: @user.gender || "unspecified",
            created_at: @user.created_at,
            # 다른 사용자에게는 제한된 정보만 제공
          }
        }
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
          render json: { error: current_user.errors.full_messages.join(', ') }, status: :unprocessable_entity
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
          render json: { error: current_user.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.warn("파라미터 누락: #{e.message}")
        render json: { error: "비밀번호 변경에 필요한 정보가 누락되었습니다." }, status: :bad_request
      rescue => e
        Rails.logger.error("비밀번호 변경 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "비밀번호 변경 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end
    
    private
    
    def set_user
      @user = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.warn("사용자를 찾을 수 없음: ID #{params[:id]}")
      render json: { error: "해당 사용자를 찾을 수 없습니다." }, status: :not_found
    end
  end
end