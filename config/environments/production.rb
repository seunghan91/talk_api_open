require "active_support/core_ext/integer/time"
require "logger"  # 명시적으로 Logger 로드

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present? || ENV["RENDER"].present?
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{30.days.to_i}"
  }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :render

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ENV["FORCE_SSL"].present? ? ENV["FORCE_SSL"] == "true" : true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new "app-name")

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)

    # 배포 직후 디버깅을 위해 로그 레벨을 info로 설정 (나중에 warn으로 변경 가능)
    config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym

    # Redis 연결 로깅 활성화 (배포 후 확인용)
    Redis.exists_returns_integer = true # 경고 제거
  end

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "warn")

  # Use a different cache store in production.
  # Using Rails built-in :redis_cache_store (not redis-rails gem)
  # This provides better integration with Rails and proper connection pooling
  redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

  # Detect if SSL is required (external Render Redis or rediss:// protocol)
  is_external_redis = redis_url.start_with?("rediss://") ||
                      (redis_url.include?(".render.com") && !redis_url.include?("localhost"))

  cache_redis_options = {
    url: redis_url,
    expires_in: 1.day,
    namespace: "talkk_cache",
    connect_timeout: 5,
    read_timeout: 1,
    write_timeout: 1,
    reconnect_attempts: 3,
    error_handler: -> (method:, returning:, exception:) {
      Rails.logger.error("Redis Cache Error: #{method} failed with #{exception.class}: #{exception.message}")
      # Report to Sentry if available
      Sentry.capture_exception(exception, extra: { method: method, returning: returning }) if defined?(Sentry)
    }
  }

  # Add SSL configuration for external Redis connections
  cache_redis_options[:ssl] = true if is_external_redis

  config.cache_store = :redis_cache_store, cache_redis_options

  config.swagger_root = Rails.root.join("swagger").to_s
  # 정적접근 허용
  config.public_file_server.enabled = true
  # Use a real queuing backend for Active Job (and separate queues per environment).
  config.active_job.queue_adapter = :sidekiq
  config.active_job.queue_name_prefix = "talkk_api_production"

  # Disable caching for Action Mailer templates even if Action Controller
  # caching is enabled.
  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  # config.active_record.attributes_for_inspect = [ :id ] # Rails 7.2 이상에서만 지원됨

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  # Lograge 설정 - 구조화된 로깅 및 노이즈 제거
  config.lograge.enabled = true
  config.lograge.custom_options = lambda do |event|
    {
      status: event.payload[:status],
      method: event.payload[:method],
      path: event.payload[:path],
      controller: event.payload[:controller],
      action: event.payload[:action],
      duration: event.duration.round(2),
      view: event.payload[:view_runtime]&.round(2),
      db: event.payload[:db_runtime]&.round(2)
    }
  end

  # 노이즈 로그 필터링
  config.lograge.ignore_custom = lambda do |event|
    status = event.payload[:status]
    path = event.payload[:path]

    # 304 Not Modified 전부 무시
    return true if status == 304

    # wallet/notifications 엔드포인트의 200, 499 98% 샘플링
    if path&.match?(%r{\A/api/v1/(wallet|notifications)})
      return true if [ 200, 499 ].include?(status) && Random.rand < 0.98
    end

    false
  end

  # JSON 포맷으로 로그 출력
  config.lograge.formatter = Lograge::Formatters::Json.new
end
