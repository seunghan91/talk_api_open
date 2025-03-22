Sidekiq.configure_server do |config|
    config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

    # sidekiq.yml 파일을 읽도록:
    rails_root = Rails.root || File.dirname(__FILE__) + "/../.."
    config_file = rails_root + "/config/sidekiq.yml"
    if File.exist?(config_file)
      yaml_data = YAML.load_file(config_file)
      config.super_fetch! if yaml_data[:super_fetch]
      # etc...
    end
  end

  Sidekiq.configure_client do |config|
    config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
  end
