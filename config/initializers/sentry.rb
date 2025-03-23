Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Rails 환경에서만 사용
  config.enabled_environments = %w[production staging]

  # 성능 모니터링 설정
  config.traces_sample_rate = 0.5
  
  # 사용자 정보 추가
  config.before_send = lambda do |event, hint|
    # Rails의 filter_parameters를 Sentry 이벤트에 적용
    event = Sentry::Rails::FilterParameters.filter_event(event)
    
    if event.request && event.user.nil?
      # 현재 사용자 정보를 이벤트에 추가
      controller = hint[:rack_env]&.controller
      if controller && controller.respond_to?(:current_user) && controller.current_user
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
