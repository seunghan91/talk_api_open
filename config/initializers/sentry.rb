Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Rails 환경에서만 활성화
  config.enabled_environments = %w[production staging]

  # 성능 모니터링 설정 (필요 시 설정)
  config.traces_sample_rate = 0.5

  # 사용자 정보 추가 및 민감 정보 필터링
  config.send_default_pii = true
  
  config.before_send = lambda do |event, hint|
    event = Sentry::Rails::FilterParameters.filter_event(event)
    
    if event.request && event.user.nil?
      controller = hint[:rack_env]&.controller
      if controller&.respond_to?(:current_user) && controller.current_user
        event.user = {
          id: controller.current_user.id,
          nickname: controller.current_user.nickname,
          phone_number: controller.current_user.phone_number.to_s.gsub(/\d(?=\d{4})/, "*")
        }
      end
    end
    
    event
  end
end