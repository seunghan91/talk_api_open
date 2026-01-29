# app/controllers/api/v1/auth/phone_verifications_controller.rb
module Api
  module V1
    module Auth
      class PhoneVerificationsController < Api::V1::BaseController
        # 인증이 필요한 액션에서만 authorize_request 실행
        before_action :authorize_request, except: [:create, :verify, :check, :resend]

        # POST /api/v1/auth/phone-verifications
        # 인증 코드 요청
        def create
          Rails.logger.info("인증코드 요청 파라미터: #{params.inspect}")

          # 전화번호 추출
          phone_number = params.dig(:phone_number) || params.dig(:user, :phone_number)

          unless phone_number.present?
            return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
          end

          Rails.logger.info("인증코드 요청: 전화번호 #{phone_number}")

          begin
            service = ::Auth::PhoneVerificationService.new
            result = service.send_verification_code(phone_number)

            if result[:success]
              render json: {
                message: result[:message],
                expires_at: result[:expires_at],
                user_exists: result[:user_exists],
                code: result[:code] # 개발 환경에서만 노출
              }, status: :ok
            else
              render json: { error: result[:error] }, status: :unprocessable_entity
            end
          rescue => e
            Rails.logger.error("인증코드 발송 중 오류: #{e.message}\n#{e.backtrace.join("\n")}")
            render json: { error: "인증 코드 발송에 실패했습니다." }, status: :internal_server_error
          end
        end

        # POST /api/v1/auth/phone-verifications/verify
        # 인증 코드 확인
        def verify
          Rails.logger.info("인증코드 확인 파라미터: #{params.inspect}")

          phone_number = params.dig(:phone_number) || params.dig(:user, :phone_number)
          code = params.dig(:code) || params.dig(:user, :code)

          unless phone_number.present?
            return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
          end

          unless code.present?
            return render json: { error: "인증코드를 입력해 주세요." }, status: :bad_request
          end

          Rails.logger.info("인증코드 확인: #{phone_number}, 입력 코드: #{code}")

          begin
            service = ::Auth::PhoneVerificationService.new
            result = service.verify_code(phone_number, code)

            if result[:success]
              render json: {
                message: result[:message],
                user_exists: result[:user_exists],
                user: result[:user],
                verification_status: result[:verification_status]
              }, status: :ok
            else
              render json: {
                error: result[:error],
                verification_required: result[:verification_required],
                verification_status: result[:verification_status]
              }, status: :unprocessable_entity
            end
          rescue => e
            Rails.logger.error("인증코드 확인 중 오류: #{e.message}")
            render json: { error: "인증 확인 중 오류가 발생했습니다." }, status: :internal_server_error
          end
        end

        # POST /api/v1/auth/check_phone
        # 전화번호 존재 여부 확인
        def check
          phone_number = params.dig(:phone_number) || params.dig(:user, :phone_number)

          unless phone_number.present?
            return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
          end

          Rails.logger.info("전화번호 확인: #{phone_number}")

          begin
            user_exists = User.exists?(phone_number: phone_number)

            render json: {
              exists: user_exists,
              message: user_exists ? "이미 등록된 전화번호입니다." : "사용 가능한 전화번호입니다."
            }, status: :ok

            Rails.logger.info("전화번호 확인 결과: #{phone_number}, 존재 여부: #{user_exists}")
          rescue => e
            Rails.logger.error("전화번호 확인 중 오류: #{e.message}")
            render json: { error: "전화번호 확인 중 오류가 발생했습니다." }, status: :internal_server_error
          end
        end

        # POST /api/v1/auth/phone-verifications/resend
        # 인증 코드 재전송
        def resend
          phone_number = params.dig(:phone_number) || params.dig(:user, :phone_number)

          unless phone_number.present?
            return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
          end

          begin
            service = ::Auth::PhoneVerificationService.new
            result = service.resend_verification_code(phone_number)

            if result[:success]
              render json: {
                message: result[:message],
                expires_at: result[:expires_at],
                wait_seconds: result[:wait_seconds]
              }, status: :ok
            else
              render json: {
                error: result[:error],
                wait_seconds: result[:wait_seconds]
              }, status: result[:status] || :unprocessable_entity
            end
          rescue => e
            Rails.logger.error("인증코드 재전송 중 오류: #{e.message}")
            render json: { error: "인증 코드 재전송에 실패했습니다." }, status: :internal_server_error
          end
        end
      end
    end
  end
end 