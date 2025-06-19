# Render 환경에서 노이즈 로그 스로틀링
# 동일한 에러가 반복될 때 로그 빈도 제한

class LogThrottle
  def initialize(app)
    @app = app
    @error_counts = Hash.new(0)
    @last_log_times = Hash.new(0)
    @throttle_duration = 60 # 1분
    @max_logs_per_minute = 5
  end

  def call(env)
    @app.call(env)
  rescue => exception
    error_key = "#{exception.class.name}:#{exception.message.truncate(100)}"
    current_time = Time.current.to_i
    
    # 동일한 에러가 1분 내에 5번 이상 발생하면 스로틀링
    if should_log_error?(error_key, current_time)
      Rails.logger.error("[THROTTLED] #{exception.class.name}: #{exception.message}")
      Rails.logger.error(exception.backtrace.first(5).join("\n")) if exception.backtrace
      
      @last_log_times[error_key] = current_time
      @error_counts[error_key] += 1
    end
    
    raise exception
  end

  private

  def should_log_error?(error_key, current_time)
    last_log_time = @last_log_times[error_key]
    
    # 첫 번째 로그이거나 스로틀 시간이 지났으면 허용
    if last_log_time == 0 || (current_time - last_log_time) >= @throttle_duration
      @error_counts[error_key] = 0
      return true
    end
    
    # 스로틀 시간 내에서 최대 허용 횟수 확인
    @error_counts[error_key] < @max_logs_per_minute
  end
end

# 프로덕션 환경에서만 활성화
if Rails.env.production?
  Rails.application.config.middleware.use LogThrottle
end