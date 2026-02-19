# config/initializers/cors.rb
# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

# Determine allowed origins based on environment.
# - Production/staging: set ALLOWED_ORIGINS env var (comma-separated).
#   e.g. ALLOWED_ORIGINS=https://talkk.app,https://admin.talkk.app
# - Development/test: localhost origins for Vite dev server and Rails.
# - Fallback: empty array (deny all cross-origin requests).
#   Flutter mobile app uses direct HTTP, not browser CORS, so this is safe.
allowed = if ENV["ALLOWED_ORIGINS"].present?
            ENV["ALLOWED_ORIGINS"].split(",").map(&:strip)
          elsif Rails.env.development? || Rails.env.test?
            [
              "http://localhost:3000",
              "http://localhost:3100",
              "http://localhost:5173",
              "http://127.0.0.1:3000",
              "http://127.0.0.1:3100",
              "http://127.0.0.1:5173"
            ]
          else
            []
          end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed)

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization" ]
  end
end
