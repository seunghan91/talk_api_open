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

# SSL 필요 여부 자동 감지
# rediss:// 프로토콜이거나 외부 render.com 도메인인 경우 SSL 필요
is_external_url = redis_url.start_with?('rediss://') || 
                 (redis_url.include?('.render.com') && !redis_url.include?('localhost'))

Rails.logger.info("Sidekiq: Redis connection type: #{is_external_url ? 'External (SSL enabled)' : 'Internal (SSL disabled)'}")

# 서버 구성 (워커)
Sidekiq.configure_server do |config|
  # 향상된 옵션으로 Redis 구성
  redis_options = { 
    url: redis_url,
    network_timeout: 5,
    pool_timeout: 5,
    reconnect_attempts: 3
  }
  
  # 외부 URL인 경우에만 SSL 활성화
  redis_options[:ssl] = true if is_external_url
  
  config.redis = redis_options
  
  # 실패한 작업 자동 재시도 설정 개선
  config.failures_max_count = 5000  # 최대 실패 작업 저장 수
  config.failures_default_mode = :exhausted  # exhausted 모드: 모든 재시도 실패 후에 저장
  
  # 작업 재시도 전략 설정
  # 처음 시도 후 30초, 1분, 5분, 15분, 30분 간격으로 최대 5번 재시도
  config.default_retries = 5
  
  # 특정 작업 클래스에 대한 추가 처리
  # 푸시 알림 처리를 위한 특별 처리
  config.death_handlers << -> (job, ex) do
    job_class = job['class']
    job_args = job['args']
    
    # 중요 작업(특히 알림 관련)일 경우 로깅 및 추가 조치
    if ['NotificationWorker', 'BroadcastWorker'].include?(job_class)
      Rails.logger.error("[CRITICAL] 중요 작업 영구 실패: #{job_class} (jid: #{job['jid']})
내용: #{job_args}
오류: #{ex.message}")
      
      # 중요 작업 실패 시 관리자 알림 (선택적)
      # 실제 구현은 추후 AdminAlertService 클래스 작성 후 활성화
      # AdminAlertService.broadcast("푸시 알림 작업 실패: #{ex.message}") if defined?(AdminAlertService)
      
      # 중요 알림 작업의 경우 마지막 시도로 이메일 대체 발송 등 구현 가능
      if job_class == 'NotificationWorker' && job_args.present?
        user_id = job_args[0]
        notification_type = job_args[1]
        Rails.logger.info("사용자 ID #{user_id}에게 #{notification_type} 알림 전송 실패, 대체 방법 고려 필요")
      end
    end
  end
  
  # 오류 처리 확장 - error_handlers는 Sidekiq 7.3.9에서 제거됨
  # 대신 exception_handlers 사용하지만 하위 호환성 유지
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
  redis_options = { 
    url: redis_url,
    network_timeout: 5,
    pool_timeout: 5,
    reconnect_attempts: 3
  }
  
  # 외부 URL인 경우에만 SSL 활성화
  redis_options[:ssl] = true if is_external_url
  
  config.redis = redis_options
end

# Sidekiq 설정 로깅
concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', 5)
Rails.logger.info("Sidekiq configured with concurrency: #{concurrency}")
Rails.logger.info("Sidekiq initialized successfully")
