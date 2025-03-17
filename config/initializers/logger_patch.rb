# Rails 7.0과 Ruby 3.1.0 호환성 문제 해결을 위한 패치
require 'logger'

# Logger 클래스가 로드되었는지 확인
unless defined?(::Logger)
  # 표준 라이브러리에서 Logger 로드
  require 'logger'
end

# ActiveSupport::Logger가 로드되기 전에 Logger::Severity 상수 확인
unless defined?(::Logger::Severity)
  module ::Logger
    module Severity
      DEBUG = 0
      INFO = 1
      WARN = 2
      ERROR = 3
      FATAL = 4
      UNKNOWN = 5
    end
    include Severity
  end
end 