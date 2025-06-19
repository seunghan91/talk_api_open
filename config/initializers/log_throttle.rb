# 499 에러 로그 스로틀링 설정
# 동일한 엔드포인트의 499 에러를 5분에 1회만 기록하여 로그 과부하 방지

ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
  if payload[:status] == 499
    key = "throttle_wallet_499:#{payload[:path]}"
    next if Rails.cache.exist?(key)

    Rails.cache.write(key, true, expires_in: 5.minutes) # 5분에 1회만 기록
    Rails.logger.warn("[499 Throttled] #{payload[:method]} #{payload[:path]} - Client disconnected")
  end
end
