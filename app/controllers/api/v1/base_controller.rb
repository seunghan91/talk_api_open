module Api
  module V1
    class BaseController < ApplicationController
      before_action :log_api_request

      # 추가 예외 처리
      rescue_from StandardError do |e|
        Sentry.capture_exception(e) if defined?(Sentry)
        Rails.logger.error("예상치 못한 오류: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요." }, status: :internal_server_error
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        Rails.logger.warn("리소스를 찾을 수 없음: #{e.message}")
        render json: { error: "요청하신 리소스를 찾을 수 없습니다." }, status: :not_found
      end

      rescue_from ActionController::ParameterMissing do |e|
        Rails.logger.warn("필수 파라미터 누락: #{e.message}")
        render json: { error: "필수 파라미터가 누락되었습니다: #{e.param}" }, status: :bad_request
      end

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

      # 사용자 활성 상태 확인
      def ensure_user_active
        return true if current_user.nil? # authorize_request에서 이미 처리

        unless current_user.status_active?
          render json: {
            error: "현재 계정 상태로는 이 기능을 사용할 수 없습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :forbidden
          return false
        end
        true
      end

      # 요청된 리소스에 대한 사용자 권한 확인
      def authorize_resource(resource, owner_id_field = :user_id)
        return false unless current_user

        unless resource.send(owner_id_field) == current_user.id
          render json: {
            error: "이 리소스에 접근할 권한이 없습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :forbidden
          return false
        end
        true
      end
    end
  end
end
