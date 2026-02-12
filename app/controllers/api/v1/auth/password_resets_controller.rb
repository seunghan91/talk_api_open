module Api
  module V1
    module Auth
      class PasswordResetsController < Api::V1::BaseController
        # 비밀번호 재설정은 인증 없이 전화번호+인증코드로 처리

        # POST /api/v1/auth/password_resets
        def create
          perform_password_reset
        end

        # PATCH/PUT /api/v1/auth/password_resets/:id
        # id를 사용하지 않는 호환 엔드포인트
        def update
          perform_password_reset
        end

        private

        def perform_password_reset
          phone_number = reset_params[:phone_number]
          code = reset_params[:code]
          new_password = reset_params[:password]
          password_confirmation = reset_params[:password_confirmation].presence || new_password

          if phone_number.blank? || code.blank? || new_password.blank?
            return render json: { error: "전화번호, 인증코드, 새 비밀번호를 입력해주세요." }, status: :bad_request
          end

          user = User.find_by(phone_number: phone_number)
          return render json: { error: "해당 전화번호로 가입된 사용자가 없습니다." }, status: :not_found unless user

          verification = PhoneVerification.find_by(phone_number: phone_number)
          unless verification&.verified? && verification.code == code && verification.expires_at&.future?
            return render json: { error: "유효하지 않거나 만료된 인증코드입니다." }, status: :unprocessable_entity
          end

          if new_password.length < 6
            return render json: { error: "비밀번호는 최소 6자 이상이어야 합니다." }, status: :unprocessable_entity
          end

          if new_password != password_confirmation
            return render json: { error: "비밀번호 확인이 일치하지 않습니다." }, status: :unprocessable_entity
          end

          user.password = new_password
          user.password_confirmation = password_confirmation

          if user.save
            verification.destroy
            render json: { message: "비밀번호가 성공적으로 변경되었습니다." }, status: :ok
          else
            render json: { error: user.errors.full_messages.join(", ") }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("비밀번호 재설정 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "비밀번호 재설정 중 오류가 발생했습니다." }, status: :internal_server_error
        end

        def reset_params
          if params[:user].present?
            params.require(:user).permit(:phone_number, :code, :password, :password_confirmation)
          else
            params.permit(:phone_number, :code, :password, :password_confirmation)
          end
        end
      end
    end
  end
end
