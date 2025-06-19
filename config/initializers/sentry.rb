Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.environment = Rails.env

  config.enabled_environments = %w[production staging]

  config.traces_sample_rate = 0.5

  config.send_default_pii = true

  config.before_send = lambda do |event, hint|
    # Rails의 filter_parameters를 직접 적용
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    
    # 이벤트 데이터를 필터링
    if event.request&.data
      event.request.data = filter.filter(event.request.data)
    end
    
    # 사용자 정보 추가
    if event.request && event.user.nil?
      controller = hint[:rack_env]&.dig("action_controller.instance")
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
