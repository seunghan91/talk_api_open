# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :authorize_request

  attr_reader :current_user

  private

  def authorize_request
    begin
      header = request.headers['Authorization']
      Rails.logger.debug "Authorization 헤더: #{header}"
      
      if header.blank?
        Rails.logger.warn "Authorization 헤더 누락"
        return render_unauthorized
      end
      
      token = header.split(' ').last
      Rails.logger.debug "추출된 토큰: #{token}"
      
      # 토큰 디코딩 시도
      begin
        decoded = AuthToken.decode(token)
        Rails.logger.debug "디코딩된 토큰 내용: #{decoded.inspect}"
        
        if decoded && decoded[:user_id]
          @current_user = User.find_by(id: decoded[:user_id])
          
          if @current_user
            Rails.logger.info "인증 성공: 사용자 ID #{@current_user.id}"
          else
            Rails.logger.warn "토큰의 user_id에 해당하는 사용자가 없음: #{decoded[:user_id]}"
            return render_unauthorized
          end
        else
          Rails.logger.warn "토큰에 user_id가 없음"
          return render_unauthorized
        end
      rescue JWT::ExpiredSignature
        Rails.logger.warn "만료된 토큰: #{token}"
        return render json: { error: '인증 토큰이 만료되었습니다. 다시 로그인해주세요.' }, status: :unauthorized
      rescue JWT::DecodeError => e
        Rails.logger.warn "유효하지 않은 토큰: #{e.message}"
        return render_unauthorized
      rescue => e
        Rails.logger.error "토큰 디코딩 중 예상치 못한 오류: #{e.message}\n#{e.backtrace.join("\n")}"
        return render_unauthorized
      end
    rescue => e
      Rails.logger.error "인증 처리 중 예외 발생: #{e.message}\n#{e.backtrace.join("\n")}"
      return render_unauthorized
    end
  end
  
  def render_unauthorized
    render json: { error: '인증이 필요합니다. 로그인 후 이용해주세요.' }, status: :unauthorized
  end
end