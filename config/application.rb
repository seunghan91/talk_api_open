require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TalkkApi
  class Application < Rails::Application
    # Rails 7.0 호환성을 위해 버전 변경
    config.load_defaults 7.0
    # 이 줄은 Rails 7.2에서만 사용되므로 주석 처리
    # config.autoload_lib(ignore: %w[assets tasks])

    # 암호화 코드
    config.active_record.encryption.primary_key = Rails.application.credentials.dig(:active_record_encryption, :primary_key)
    config.active_record.encryption.deterministic_key = Rails.application.credentials.dig(:active_record_encryption, :deterministic_key)
    config.active_record.encryption.key_derivation_salt = Rails.application.credentials.dig(:active_record_encryption, :key_derivation_salt)

    config.autoload_paths << Rails.root.join("lib")
    
    # 로그 샘플링 미들웨어 추가
    config.middleware.insert_before Rails::Rack::Logger, LogSample499

    # RailsAdmin을 위해 필요한 미들웨어 추가
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Flash
    config.middleware.use Rack::MethodOverride
    config.middleware.use ActionDispatch::Session::CookieStore, { key: "_talkk_api_session" }

    # API 전용 모드 끄기 (RailsAdmin을 위해)
    config.api_only = false  # 또는 이 줄을 아예 삭제

    # secret_key_base 설정 (환경 변수가 없는 경우 기본값 사용)
    config.secret_key_base = ENV["SECRET_KEY_BASE"] || "a58d5f62659e89d8c2ae1949570b980619361bfc08ff9a612d1b563fd7ce51250fab4db654dfb90a4f62981e6df12b2d6a49d92d4f56b8c8bacd49f4ccc7879e"

    # CORS 설정
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins "*"
        resource "*",
          headers: :any,
          methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
          expose: [ "Authorization" ]
      end
    end

    # Active Storage 설정
    config.active_storage.variant_processor = :mini_magick

    # 타임존 설정
    config.time_zone = "Seoul"
    config.active_record.default_timezone = :local

    # 인앱 결제 설정
    config.iap_prefix = "com.talkapp.talkk2025"

    # 애플 인앱 결제 검증 URL
    config.apple_iap_verify_url = Rails.env.production? ?
      "https://buy.itunes.apple.com/verifyReceipt" :
      "https://sandbox.itunes.apple.com/verifyReceipt"

    # 구글 인앱 결제 설정 (추후 구현 시 사용)
    # config.google_play_package_name = 'com.talkapp.talkk2025'
  end
end
