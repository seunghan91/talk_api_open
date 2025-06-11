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
    filtered_event_hash = filter.filter(event.to_hash)
    event = Sentry::Event.new(filtered_event_hash)

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
