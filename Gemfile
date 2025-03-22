source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.0"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.0.8"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 5.0"

# Nokogiri 버전 제한 (호환성 문제 해결)
gem "nokogiri", "~> 1.16.0"

# FFI 버전 제한 (호환성 문제 해결)
gem "ffi", "~> 1.15.5"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors"

# JWT for authentication
gem "jwt"

# Background jobs
gem "sidekiq", "~> 7.1"
gem "redis", "~> 4.0"

# 필요한 기본 gem만 유지하고 나머지는 배포 성공 후 추가
# gem 'sidekiq-cron'
# gem 'rails_admin', '~> 3.0'
# gem "sassc-rails"
# gem "sprockets-rails" # RailsAdmin에 필요한 에셋 파이프라인
# gem "importmap-rails" # JavaScript 모듈 관리
# gem "turbo-rails"     # Hotwire 기능 (RailsAdmin UI에 도움될 수 있음)

# 명시적으로 logger gem 추가
gem "logger", "~> 1.6"

# 알림을 위한 Expo push notification
gem "exponent-server-sdk"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# API 문서화를 위한 Swagger 도구
gem "rswag-api"
gem "rswag-ui"
gem "rswag-specs"

# 에러 모니터링 도구
gem "sentry-rails"
gem "sentry-ruby"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Testing
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
  gem "annotate"
end

group :test do
  gem "shoulda-matchers"
  gem "database_cleaner"
end
