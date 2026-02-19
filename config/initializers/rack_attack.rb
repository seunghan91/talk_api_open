# config/initializers/rack_attack.rb
#
# Rack::Attack configuration for rate limiting and request throttling.
# Uses Rails.cache (Solid Cache) as the default cache store.

class Rack::Attack
  # Use Rails.cache as the backing store (Solid Cache in this project)
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # ---------------------------------------------------------------------------
  # Safelists
  # ---------------------------------------------------------------------------

  # Always allow health check endpoints through without throttling
  safelist("allow-health-checks") do |req|
    req.path == "/health" ||
      req.path == "/api/health_check" ||
      req.path.start_with?("/health/")
  end

  # Allow localhost in development/test
  safelist("allow-localhost") do |req|
    "127.0.0.1" == req.ip || "::1" == req.ip
  end if Rails.env.development? || Rails.env.test?

  # ---------------------------------------------------------------------------
  # Throttles
  # ---------------------------------------------------------------------------

  # 1. SMS Phone Verification - strict limit to prevent SMS abuse
  #    5 requests per phone number per hour
  throttle("sms/phone", limit: 5, period: 1.hour) do |req|
    if req.path.match?(%r{/api/v1/auth/phone.verifications}) && req.post?
      # Extract phone number from request body
      begin
        body = JSON.parse(req.body.read)
        req.body.rewind
        body["phone_number"] || body.dig("user", "phone_number")
      rescue JSON::ParserError
        nil
      end
    end
  end

  # 2. SMS Phone Verification - also limit by IP to prevent distributed abuse
  #    10 requests per IP per hour
  throttle("sms/ip", limit: 10, period: 1.hour) do |req|
    if req.path.match?(%r{/api/v1/auth/phone.verifications}) && req.post?
      req.ip
    end
  end

  # 3. Login attempts - prevent brute force
  #    10 attempts per IP per hour
  throttle("login/ip", limit: 10, period: 1.hour) do |req|
    if (req.path == "/api/v1/auth/sessions" || req.path == "/api/v1/auth/login") && req.post?
      req.ip
    end
  end

  # 4. Login attempts - also throttle per phone number
  #    10 attempts per phone number per hour
  throttle("login/phone", limit: 10, period: 1.hour) do |req|
    if (req.path == "/api/v1/auth/sessions" || req.path == "/api/v1/auth/login") && req.post?
      begin
        body = JSON.parse(req.body.read)
        req.body.rewind
        body["phone_number"] || body.dig("user", "phone_number")
      rescue JSON::ParserError
        nil
      end
    end
  end

  # 5. Registration - prevent mass account creation
  #    5 registrations per IP per hour
  throttle("registration/ip", limit: 5, period: 1.hour) do |req|
    if req.path.match?(%r{/api/v1/auth/registrations}) && req.post?
      req.ip
    end
  end

  # 6. Password reset - prevent abuse
  #    5 requests per IP per hour
  throttle("password-reset/ip", limit: 5, period: 1.hour) do |req|
    if req.path.match?(%r{/api/v1/auth/password.resets}) && req.post?
      req.ip
    end
  end

  # 7. General API - authenticated user rate limit
  #    300 requests per minute per user (via Authorization header)
  throttle("api/user", limit: 300, period: 1.minute) do |req|
    if req.path.start_with?("/api/")
      # Use session token as discriminator for authenticated requests
      req.env["HTTP_AUTHORIZATION"]&.split(" ")&.last
    end
  end

  # 8. General API - unauthenticated IP-based rate limit
  #    60 requests per minute per IP for unauthenticated requests
  throttle("api/ip", limit: 60, period: 1.minute) do |req|
    if req.path.start_with?("/api/") && req.env["HTTP_AUTHORIZATION"].blank?
      req.ip
    end
  end

  # ---------------------------------------------------------------------------
  # Blocklists
  # ---------------------------------------------------------------------------

  # Block IPs that have been flagged (stored in cache with "block:" prefix)
  # Usage: Rack::Attack.cache.write("block:ip:1.2.3.4", true, expires_in: 1.hour)
  blocklist("block-flagged-ips") do |req|
    Rack::Attack.cache.read("block:ip:#{req.ip}")
  end

  # ---------------------------------------------------------------------------
  # Custom Responses
  # ---------------------------------------------------------------------------

  # Return JSON response for throttled requests (429 Too Many Requests)
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])

    headers = {
      "Content-Type" => "application/json; charset=utf-8",
      "Retry-After" => retry_after.to_s
    }

    body = {
      error: "요청이 너무 많습니다. 잠시 후 다시 시도해주세요.",
      retry_after: retry_after
    }.to_json

    [ 429, headers, [body] ]
  end

  # Return JSON response for blocked requests (403 Forbidden)
  self.blocklisted_responder = lambda do |request|
    headers = { "Content-Type" => "application/json; charset=utf-8" }
    body = { error: "접근이 차단되었습니다." }.to_json

    [ 403, headers, [body] ]
  end

  # ---------------------------------------------------------------------------
  # Instrumentation (logging)
  # ---------------------------------------------------------------------------

  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn(
      "[Rack::Attack] Throttled #{req.env['rack.attack.match_discriminator']} " \
      "#{req.ip} #{req.request_method} #{req.path} " \
      "(matched: #{req.env['rack.attack.matched']})"
    )
  end

  ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn(
      "[Rack::Attack] Blocked #{req.ip} #{req.request_method} #{req.path}"
    )
  end
end
