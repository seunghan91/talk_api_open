# app/controllers/api/v1/auth/sessions_controller.rb
module Api
  module V1
    module Auth
      class SessionsController < Api::V1::BaseController
        # 로그인/로그아웃은 인증 상태에 따라 다름
        before_action :authorize_request, only: [:destroy, :current]

        # POST /api/v1/auth/sessions (로그인)
        def create
          Rails.logger.info("로그인 요청 파라미터: #{params.inspect}")

          # Command 패턴 사용
          command = ::Auth::LoginCommand.new(
            phone_number: login_params[:phone_number],
            password: login_params[:password]
          )

          result = command.execute

          if result[:success]
            render json: {
              token: result[:token],
              user: result[:user],
              message: "로그인에 성공했습니다."
            }, status: :ok
          else
            render json: {
              error: result[:error]
            }, status: result[:status] || :unauthorized
          end
        rescue => e
          Rails.logger.error("로그인 중 오류 발생: #{e.message}")
          render json: { error: "로그인 중 오류가 발생했습니다." }, status: :internal_server_error
        end

        # DELETE /api/v1/auth/sessions (로그아웃)
        def destroy
          # JWT는 stateless이므로 클라이언트에서 토큰을 삭제하면 됨
          # 필요시 토큰 블랙리스트 관리 가능
          
          # 로그아웃 이벤트 발생
          LogoutEvent.new(user: current_user).publish
          
          render json: {
            message: "로그아웃되었습니다."
          }, status: :ok
        end

        # GET /api/v1/auth/sessions/current (현재 로그인 정보)
        def current
          render json: {
            user: serialize_current_user,
            authenticated: true
          }, status: :ok
        end

        private

        def login_params
          params.require(:user).permit(:phone_number, :password)
        rescue ActionController::ParameterMissing
          # user 네임스페이스가 없는 경우 처리
          params.permit(:phone_number, :password)
        end

        def serialize_current_user
          {
            id: current_user.id,
            nickname: current_user.nickname,
            phone_number: current_user.phone_number,
            last_login_at: current_user.last_login_at,
            created_at: current_user.created_at
          }
        end
      end
    end
  end
end 