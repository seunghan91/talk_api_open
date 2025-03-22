# JWT 시크릿 키 설정
# 환경 변수에 SECRET_KEY_BASE가 없는 경우 Rails credentials에서 가져옵니다.
# 실제 프로덕션 환경에서는 반드시 환경 변수나 credentials가 설정되어 있어야 합니다.

unless ENV['SECRET_KEY_BASE'].present?
  if Rails.application.credentials.secret_key_base.present?
    ENV['SECRET_KEY_BASE'] = Rails.application.credentials.secret_key_base
    Rails.logger.info("환경 변수 SECRET_KEY_BASE가 설정되지 않아 Rails credentials의 secret_key_base를 사용합니다.")
  else
    Rails.logger.warn("환경 변수 SECRET_KEY_BASE와 Rails credentials.secret_key_base 모두 설정되지 않았습니다.")
    Rails.logger.warn("JWT 인증이 제대로 작동하지 않을 수 있습니다. Render 환경변수 설정에서 SECRET_KEY_BASE를 추가해주세요.")
  end
end 