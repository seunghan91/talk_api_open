module Api
  module V1
    module Auth
      class AuthController < Api::V1::BaseController
        skip_before_action :authorize_request, only: [:request_code, :verify_code, :register, :login]
        
        # 로그인 및 회원가입 관련 로직은 Api::AuthController에서 이전
        
        # @swagger
        # /api/v1/auth/login:
        #   post:
        #     summary: 사용자 로그인
        #     tags: [인증]
        #     parameters:
        #       - name: phone_number
        #         in: body
        #         required: true
        #         type: string
        #         description: 사용자 전화번호
        #       - name: password
        #         in: body
        #         required: true
        #         type: string
        #         description: 사용자 비밀번호
        #     responses:
        #       200:
        #         description: 로그인 성공
        #         schema:
        #           type: object
        #           properties:
        #             token:
        #               type: string
        #             user:
        #               type: object
        #       401:
        #         description: 인증 실패
        def login
          Rails.logger.info("로그인 요청: #{params[:phone_number]}")
          
          if Api::AuthController.instance_methods(false).include?(:login)
            # 기존 컨트롤러 메서드 호출
            Api::AuthController.new.login
          else
            render json: { error: "메서드가 구현되지 않았습니다." }, status: :not_implemented
          end
        end

        # 다른 인증 메서드도 유사하게 구현

        private

        def auth_params
          params.permit(:phone_number, :password, :nickname, :code, :verification_id)
        end
      end
    end
  end
end 