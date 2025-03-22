# JWT 시크릿 키 설정
# 환경 변수에 SECRET_KEY_BASE가 없는 경우 경고 로그를 남깁니다.
# 실제 프로덕션 환경에서는 반드시 환경 변수를 설정해야 합니다.

unless ENV['SECRET_KEY_BASE'].present?
  Rails.logger.warn("환경 변수 SECRET_KEY_BASE가 설정되지 않았습니다. JWT 인증이 제대로 작동하지 않을 수 있습니다.")
  Rails.logger.warn("Render 환경변수 설정에서 SECRET_KEY_BASE를 추가해주세요.")
end 