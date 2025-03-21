module Api
  module V1
    class BaseController < ApplicationController
      before_action :log_api_request

      private

      def log_api_request
        Rails.logger.info("API v1 요청: #{request.method} #{request.path}")
        Rails.logger.debug("  파라미터: #{params.to_unsafe_h.to_json}")
        Rails.logger.debug("  헤더: Authorization=#{request.headers['Authorization'] ? '설정됨' : '없음'}")
      end

      # API 응답 표준화
      def render_success(data = {}, status = :ok)
        render json: { success: true, data: data }, status: status
      end

      def render_error(message, status = :unprocessable_entity, errors = nil)
        response = {
          success: false,
          error: message
        }
        response[:errors] = errors if errors
        render json: response, status: status
      end

      # 현재 사용자 정보를 담는 메소드 (오버라이드)
      def current_user
        @current_user ||= User.find(@current_user_id) if @current_user_id
      end

      # API 요청 인증을 처리하는 메소드
      def authorize_request
        header = request.headers["Authorization"]

        begin
          if header.present?
            token = header.split(" ").last
            decoded = AuthToken.decode(token)
            @current_user_id = decoded[:user_id]
          else
            raise JWT::DecodeError.new("토큰이 제공되지 않았습니다")
          end
        rescue JWT::DecodeError => e
          Rails.logger.error("JWT 디코드 오류: #{e.message}")
          render json: { error: "유효하지 않은 토큰입니다." }, status: :unauthorized
        rescue JWT::ExpiredSignature
          Rails.logger.warn("만료된 토큰으로 접근 시도: #{header}")
          render json: { error: "만료된 토큰입니다. 다시 로그인해주세요." }, status: :unauthorized
        rescue JWT::VerificationError
          Rails.logger.warn("변조된 토큰으로 접근 시도: #{header}")
          render json: { error: "변조된 토큰입니다." }, status: :unauthorized
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.warn("사용자를 찾을 수 없음: #{@current_user_id}")
          render json: { error: "존재하지 않는 사용자입니다." }, status: :unauthorized
        rescue => e
          Rails.logger.error("인증 중 예상치 못한 오류: #{e.message}")
          render json: { error: "인증 처리 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end
    end
  end
end
