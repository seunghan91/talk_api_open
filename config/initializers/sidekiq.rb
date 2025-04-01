require 'sidekiq'

# 로깅 기능 확장
def log_with_sanitized_url(message, url)
  sanitized_url = url.gsub(/:[^:]*@/, ':****@')
  Rails.logger.info("Sidekiq: #{message} #{sanitized_url}")
end

# Redis URL 확인 및 연결 정보 출력
# Redis URL을 환경 변수에서 가져오거나 기본값 설정
# Render에서는 환경 변수 이름이 REDIS_URL 대신 RENDER_REDIS_URL 또는 
# REDIS_HOST와 REDIS_PORT로 제공될 수 있음
redis_url = if ENV['RENDER_REDIS_URL'].present?
  ENV['RENDER_REDIS_URL']
elsif ENV['REDIS_HOST'].present? && ENV['REDIS_PORT'].present?
  "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}/0"
elsif ENV['REDIS_URL'].present?
  ENV['REDIS_URL']
else
  'redis://localhost:6379/0'
end
log_with_sanitized_url("Initializing with Redis URL:", redis_url)

# Redis URL 구문 분석 (디버깅 목적)
begin
  uri = URI.parse(redis_url)
  host = uri.host || 'localhost'
  port = uri.port || 6379
  
  Rails.logger.info("Sidekiq: Redis connection details - Host: #{host}, Port: #{port}")
rescue URI::InvalidURIError => e
  Rails.logger.error("Sidekiq: Invalid Redis URL format: #{e.message}")
end

# 서버 구성 (워커)
Sidekiq.configure_server do |config|
  # 향상된 옵션으로 Redis 구성
  config.redis = { 
    url: redis_url,
    network_timeout: 5,
    pool_timeout: 5,
    reconnect_attempts: 3,
    ssl: true
  }
  
  # 오류 처리 확장 - error_handlers는 Sidekiq 7.3.9에서 제거됨
  # 대신 exception_handlers 사용
  config.error_handlers << proc do |ex, ctx_hash|
    job_info = ctx_hash[:job] || {}
    Rails.logger.error(
      "Sidekiq error: #{ex.class} - #{ex.message}\n" +
      "Job: #{job_info['class']} - #{job_info['jid']}\n" +
      "Args: #{job_info['args']}\n" +
      "Context: #{ctx_hash}\n" +
      "Backtrace: #{ex.backtrace ? ex.backtrace[0..5].join("\n") : 'No backtrace'}"
    )
  end
  
  # Redis 연결 이벤트 수신기 추가
  config.on(:startup) do
    Rails.logger.info("Sidekiq server started successfully")
  end
  
  config.on(:shutdown) do
    Rails.logger.info("Sidekiq server shutting down")
  end
end

# 클라이언트 구성 (웹 프로세스)
Sidekiq.configure_client do |config|
  config.redis = { 
    url: redis_url,
    network_timeout: 5,
    pool_timeout: 5,
    reconnect_attempts: 3,
    ssl: true
  }
end

# Sidekiq 설정 로깅
concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', 5)
Rails.logger.info("Sidekiq configured with concurrency: #{concurrency}")
Rails.logger.info("Sidekiq initialized successfully")
