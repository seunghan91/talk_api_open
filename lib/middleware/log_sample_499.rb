# 499/304 로그 샘플링 미들웨어
# 동일한 IP+Path+Status 조합에 대해 1분에 1회만 로그 기록

module Middleware
  class LogSample499
  WINDOW = 60 # 초
  NOISE_PATHS = %r{\A/api/v1/(wallet|notifications)}i.freeze

  def initialize(app)
    @app = app
    @seen = {}
    @mutex = Mutex.new
  end

  def call(env)
    status, headers, body = @app.call(env)

    # 노이즈 로그 샘플링 적용
    if should_sample_log?(env, status)
      sample_and_log(env, status)
    end

    [ status, headers, body ]
  end

  private

  def should_sample_log?(env, status)
    path = env["PATH_INFO"]

    # 304 Not Modified - 전부 샘플링
    return true if status == 304

    # wallet/notifications 엔드포인트의 499, 200 샘플링
    return true if path&.match?(NOISE_PATHS) && [ 200, 499 ].include?(status)

    false
  end

  def sample_and_log(env, status)
    @mutex.synchronize do
      key = "#{env["REMOTE_ADDR"]}:#{env["PATH_INFO"]}:#{status}"
      current_time = Time.now.to_i
      last_logged = @seen[key] || 0

      # 1분 창 내에서 이미 로깅했으면 스킵
      return if current_time - last_logged < WINDOW

      # 로그 기록 및 타임스탬프 업데이트
      Rails.logger.debug("[SAMPLED #{status}] #{env["REQUEST_METHOD"]} #{env["PATH_INFO"]} - #{env["REMOTE_ADDR"]}")
      @seen[key] = current_time

      # 메모리 정리 (10분마다)
      cleanup_old_entries if current_time % 600 == 0
    end
  end

  def cleanup_old_entries
    current_time = Time.now.to_i
    @seen.delete_if { |_, timestamp| current_time - timestamp > WINDOW * 10 }
  end
  end
end

# Backward compatibility for any legacy references.
LogSample499 = Middleware::LogSample499 unless defined?(LogSample499)
