# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV['CORS_ORIGINS'] || '*'
    # 프로덕션에서는 ENV['CORS_ORIGINS']에 허용할 도메인 목록을 설정
    # 예: 'https://your-app.example.com,exp://exp.host'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
end