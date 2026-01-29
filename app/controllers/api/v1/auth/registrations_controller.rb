# app/controllers/api/v1/auth/registrations_controller.rb
module Api
  module V1
    module Auth
      class RegistrationsController < Api::V1::BaseController
        # 회원가입은 인증 없이 접근 가능
        before_action :authorize_request, except: [:create]

        # POST /api/v1/auth/registrations
        # 회원가입 처리
        def create
          Rails.logger.info("회원가입 요청 파라미터: #{params.inspect}")

          # Command 패턴 사용
          command = ::Auth::RegisterUserCommand.new(
            phone_number: registration_params[:phone_number],
            password: registration_params[:password],
            password_confirmation: registration_params[:password_confirmation],
            nickname: registration_params[:nickname],
            gender: registration_params[:gender]
          )

          result = command.execute

          if result[:success]
            render json: {
              token: result[:token],
              user: result[:user],
              message: "회원가입에 성공했습니다."
            }, status: :created
          else
            render json: {
              error: result[:error],
              errors: result[:errors],
              user_exists: result[:user_exists],
              verification_required: result[:verification_required],
              verification_status: result[:verification_status]
            }, status: result[:status] || :unprocessable_entity
          end
        rescue ActionController::ParameterMissing => e
          Rails.logger.warn("파라미터 누락: #{e.message}")
          render json: { error: "필수 파라미터가 누락되었습니다." }, status: :bad_request
        rescue => e
          Rails.logger.error("회원가입 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "회원가입 중 오류가 발생했습니다." }, status: :internal_server_error
        end

        # PATCH /api/v1/auth/registrations/profile
        # 프로필 업데이트
        def update_profile
          command = ::Auth::UpdateProfileCommand.new(
            user: current_user,
            nickname: profile_params[:nickname],
            gender: profile_params[:gender],
            profile_image: profile_params[:profile_image]
          )

          result = command.execute

          if result[:success]
            render json: {
              user: result[:user],
              message: "프로필이 업데이트되었습니다."
            }, status: :ok
          else
            render json: {
              error: result[:error],
              errors: result[:errors]
            }, status: :unprocessable_entity
          end
        end

        private

        def registration_params
          params.require(:user).permit(
            :phone_number,
            :password,
            :password_confirmation,
            :nickname,
            :gender
          )
        end

        def profile_params
          params.permit(:nickname, :gender, :profile_image)
        end
      end
    end
  end
end 