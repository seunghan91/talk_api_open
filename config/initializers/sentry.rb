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
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.environment = Rails.env

  config.enabled_environments = %w[production staging]

  config.traces_sample_rate = 0.5

  config.send_default_pii = true

  config.before_send = lambda do |event, hint|
    # 노이즈 에러 필터링 - Sentry Quota 절약

    # 499 Client Disconnected 에러 드롭
    if hint.dig(:rack_env, "action_dispatch.exception")&.is_a?(ActionController::ClientDisconnectedError) ||
       event.tags&.dig(:status) == 499 ||
       hint.dig(:response, :status) == 499
      return nil
    end

    # 304 Not Modified 드롭
    if event.tags&.dig(:status) == 304 || hint.dig(:response, :status) == 304
      return nil
    end

    # wallet/notifications 엔드포인트의 정상 응답 (200) 90% 샘플링
    if event.request&.url&.match?(%r{/api/v1/(wallet|notifications)}) &&
       (event.tags&.dig(:status) == 200 || hint.dig(:response, :status) == 200)
      return nil if Random.rand < 0.9
    end

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
          phone_number: mask_phone_number(controller.current_user.phone_number)
        }
      end
    end

    event
  end
end
