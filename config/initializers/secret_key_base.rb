# 환경 변수가 없는 경우 하드코딩된 값으로 secret_key_base 설정
# 주의: 이것은 임시 해결책입니다. 실제 프로덕션 환경에서는 환경 변수를 사용하세요.
# production 환경에서만 설정 적용
if Rails.env.production? || Rails.env.staging?
  Rails.application.config.secret_key_base = ENV["SECRET_KEY_BASE"] || "a58d5f62659e89d8c2ae1949570b980619361bfc08ff9a612d1b563fd7ce51250fab4db654dfb90a4f62981e6df12b2d6a49d92d4f56b8c8bacd49f4ccc7879e"
end 