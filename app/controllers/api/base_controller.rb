module Api
  class BaseController < ApplicationController
    before_action :authorize_request
    attr_reader :current_user
    
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ApiError::InvalidToken, with: :render_invalid_token
    rescue_from ApiError::TokenExpired, with: :render_token_expired
    rescue_from ApiError::Unauthorized, with: :render_unauthorized
    rescue_from ApiError::ValidationError, with: :render_validation_error
    
    private
    
    def authorize_request
      header = request.headers['Authorization']
      if header.present?
        token = header.split(' ').last
        begin
          decoded = JsonWebToken.decode(token)
          if decoded && decoded[:user_id]
            @current_user = User.find_by(id: decoded[:user_id])
          end
        rescue JWT::ExpiredSignature
          raise ApiError::TokenExpired
        rescue JWT::DecodeError
          raise ApiError::InvalidToken
        end
      end
      
      unless @current_user
        raise ApiError::Unauthorized
      end
    end
    
    def handle_standard_error(exception)
      Rails.logger.error "예외 발생: #{exception.class.name} - #{exception.message}"
      Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
      
      render json: { 
        error: "요청을 처리하는 중 오류가 발생했습니다.",
        details: exception.message
      }, status: :internal_server_error
    end
    
    def handle_record_not_found(exception)
      Rails.logger.warn "레코드 없음: #{exception.message}"
      
      render json: { 
        error: "요청한 데이터를 찾을 수 없습니다.",
        details: exception.message
      }, status: :not_found
    end
    
    def handle_parameter_missing(exception)
      Rails.logger.warn "파라미터 누락: #{exception.message}"
      
      render json: { 
        error: "필수 파라미터가 누락되었습니다.",
        details: exception.message
      }, status: :bad_request
    end
    
    def render_invalid_token
      render json: { error: 'Invalid token' }, status: :unauthorized
    end
    
    def render_token_expired
      render json: { error: 'Token expired', expired: true }, status: :unauthorized
    end
    
    def render_unauthorized
      render json: { error: 'Unauthorized access' }, status: :unauthorized
    end
    
    def render_validation_error(exception)
      render json: { error: 'Validation error', details: exception.message }, status: :unprocessable_entity
    end
  end
end