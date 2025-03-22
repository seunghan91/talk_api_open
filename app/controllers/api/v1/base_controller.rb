module Api
  module V1
    class BaseController < Api::BaseController
      before_action :log_api_request
      
      private
      
      def log_api_request
        Rails.logger.info("API v1 요청: #{request.method} #{request.path}")
        Rails.logger.debug("  파라미터: #{params.to_unsafe_h.to_json}")
        Rails.logger.debug("  헤더: Authorization=#{request.headers['Authorization'] ? '설정됨' : '없음'}")
      end
    end
  end
end 