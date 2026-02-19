# frozen_string_literal: true

# Security headers middleware
# Adds recommended security headers to all responses.
# No gem dependency - pure Rack middleware.

module Middleware
  class SecurityHeaders
    # Headers applied to every response regardless of environment.
    COMMON_HEADERS = {
      "X-Content-Type-Options"  => "nosniff",
      "X-Frame-Options"         => "DENY",
      "X-XSS-Protection"        => "0",
      "Referrer-Policy"          => "strict-origin-when-cross-origin",
      "Permissions-Policy"       => "camera=(), microphone=(), geolocation=()"
    }.freeze

    # HSTS header value - 1 year with includeSubDomains.
    HSTS_VALUE = "max-age=31536000; includeSubDomains"

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      COMMON_HEADERS.each { |key, value| headers[key] = value }

      # Only add HSTS in production to avoid locking dev/test to HTTPS.
      if Rails.env.production?
        headers["Strict-Transport-Security"] = HSTS_VALUE
      end

      [status, headers, body]
    end
  end
end
