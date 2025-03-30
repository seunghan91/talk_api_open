require 'sidekiq'

# Ensure we get a valid Redis URL
redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
Rails.logger.info("Sidekiq initializing with Redis URL: #{redis_url.gsub(/:[^:]*@/, ':****@')}")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  
  # Additional error logging
  Sidekiq.error_handlers << proc { |ex, ctx_hash|
    Rails.logger.error("Sidekiq error: #{ex.message}\nContext: #{ctx_hash}")
  }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

# Log Sidekiq initialization success
Rails.logger.info("Sidekiq initialized successfully")
