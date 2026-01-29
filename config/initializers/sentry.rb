# 전화번호 마스킹 헬퍼 함수 (암호화된 필드 처리)
def mask_phone_number(phone)
  return "***-****-****" if phone.nil?

  phone_str = phone.to_s
  return "***-****-****" if phone_str.blank? || phone_str.length < 8

  # 전화번호 마스킹 (끝 4자리만 표시)
  phone_str.gsub(/\d(?=\d{4})/, "*")
rescue => e
  # 암호화 해독 실패 등의 경우
  "***-****-****"
end

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]

  # Sentry SDK v6: :http_logger is deprecated, use :net_http instead
  config.breadcrumbs_logger = [ :active_support_logger, :net_http ]

  config.environment = Rails.env
  config.enabled_environments = %w[production staging]

  # Performance monitoring
  config.traces_sample_rate = 0.1

  # Sentry SDK v6: Profiling support (optional, set to 0 to disable)
  config.profiles_sample_rate = 0.1

  # Include PII data (masked where appropriate)
  config.send_default_pii = true

  # Sentry SDK v6: Release tracking
  config.release = ENV.fetch("SENTRY_RELEASE", "talk-api@#{ENV.fetch('RENDER_GIT_COMMIT', 'unknown')[0..7]}")

  # Sentry SDK v6: before_send callback
  config.before_send = lambda do |event, hint|
    # 노이즈 에러 필터링 - Sentry Quota 절약

    # Sentry SDK v6: Access exception from hint using :exception key
    exception = hint[:exception]

    # 499 Client Disconnected 에러 드롭
    if exception.is_a?(ActionController::ClientDisconnectedError) ||
       event.tags&.dig(:status) == 499
      return nil
    end

    # 304 Not Modified 드롭
    if event.tags&.dig(:status) == 304
      return nil
    end

    # wallet/notifications 엔드포인트의 정상 응답 (200) 90% 샘플링
    if event.request&.url&.match?(%r{/api/v1/(wallet|notifications)}) &&
       event.tags&.dig(:status) == 200
      return nil if Random.rand < 0.9
    end

    # Rails의 filter_parameters를 직접 적용
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    # 이벤트 데이터를 필터링
    if event.request&.data
      event.request.data = filter.filter(event.request.data)
    end

    # Sentry SDK v6: Access rack_env from Sentry's scope if available
    # User information is now better handled via Sentry.set_user in controllers
    if event.request && event.user.nil?
      # Try to get user from Sentry's current scope
      scope = Sentry.get_current_scope
      if scope&.user.nil?
        # Fallback: try to get from rack_env if available
        rack_env = hint[:rack_env]
        if rack_env
          controller = rack_env["action_controller.instance"]
          if controller&.respond_to?(:current_user) && controller.current_user
            event.user = {
              id: controller.current_user.id,
              nickname: controller.current_user.nickname,
              phone_number: mask_phone_number(controller.current_user.phone_number)
            }
          end
        end
      end
    end

    event
  end
end
