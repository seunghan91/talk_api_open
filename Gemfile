source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.1"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.0"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.6"

# Security fixes
gem "nokogiri", ">= 1.18.9"
gem "thor", ">= 1.4.0"

# Ruby 3.5 compatibility
gem "ostruct"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 7.0"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors", "~> 3.0"

# JWT for authentication
gem "jwt", "~> 3.0"

# Background jobs - Solid Queue (Rails 8 native, DB-backed)
# Redis kept for caching and health check connectivity
gem "redis", "~> 5.0"

# Solid Suite (Rails 8 native)
gem "solid_queue", "~> 1.1"   # Latest: 1.3.x (DB-backed jobs, recurring tasks, async mode)
gem "solid_cache", "~> 1.0"   # Latest: 1.0.x (DB-backed cache)
gem "solid_cable", "~> 3.0"   # Latest: 3.0.x (DB-backed ActionCable)

# Soft delete
gem "discard", "~> 1.4"

# 필요한 기본 gem만 유지하고 나머지는 배포 성공 후 추가
# gem 'sidekiq-cron'
# gem 'rails_admin', '~> 3.0'
# gem "sassc-rails"
# gem "sprockets-rails" # RailsAdmin에 필요한 에셋 파이프라인
# gem "importmap-rails" # JavaScript 모듈 관리
# gem "turbo-rails"     # Hotwire 기능 (RailsAdmin UI에 도움될 수 있음)

# 명시적으로 logger gem 추가
gem "logger"

# 알림을 위한 Expo push notification
gem "exponent-server-sdk"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# API 문서화를 위한 Swagger 도구
gem "rswag-api"
gem "rswag-ui"
gem "rswag-specs"

# 에러 모니터링 도구
gem "sentry-rails", "~> 6.0"
gem "sentry-ruby", "~> 6.0"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", "~> 7.0.2", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Testing
  gem "rspec-rails", "~> 8.0"
  gem "rspec-expectations"
  gem "rspec-mocks"
  gem "rspec-support"
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
gem "kaminari"

gem "lograge", "~> 0.14.0"

# Inertia.js Rails adapter (Svelte 5 frontend)
gem "inertia_rails", "~> 3.0"

# Vite Rails integration (asset bundling)
gem "vite_rails", "~> 3.0"
