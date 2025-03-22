Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  
  # Rails 환경에서만 사용
  config.enabled_environments = %w[production staging]
  
  # 성능 모니터링 설정
  config.traces_sample_rate = 0.5
  
  # 사용자 정보 추가
  config.before_send = lambda do |event, hint|
    if event.request && event.user.nil?
      # 현재 사용자 정보를 이벤트에 추가
      controller = hint[:rack_env]&.controller
      if controller && controller.respond_to?(:current_user) && controller.current_user
        event.user = {
          id: controller.current_user.id,
          nickname: controller.current_user.nickname,
          phone_number: controller.current_user.phone_number.to_s.gsub(/\d(?=\d{4})/, '*')
        }
      end
    end
    event
  end
  
  # 민감한 정보는 Sentry에서 필터링
  # filter_parameters 메서드가 없으므로 다음과 같이 수정
  if defined?(Rails.application.config.filter_parameters)
    filter_proc = ->(event) {
      if event.request && event.request.data
        Rails.application.config.filter_parameters.each do |pattern|
          if pattern.is_a?(Regexp)
            event.request.data.each do |key, value|
              if key.to_s =~ pattern
                event.request.data[key] = "[FILTERED]"
              end
            end
          elsif pattern.is_a?(Symbol) || pattern.is_a?(String)
            if event.request.data.key?(pattern.to_s)
              event.request.data[pattern.to_s] = "[FILTERED]"
            end
          end
        end
      end
      event
    }
    config.before_send = ->(event, hint) {
      filter_proc.call(event)
      config.before_send.call(event, hint) if config.before_send
      event
    }
  end
end 