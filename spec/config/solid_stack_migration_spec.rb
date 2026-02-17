require "rails_helper"
require "erb"
require "yaml"

RSpec.describe "Solid Stack migration config" do
  it "configures development/test/staging as multi-db in database.yml" do
    rendered = ERB.new(File.read(Rails.root.join("config/database.yml"))).result
    config = YAML.safe_load(rendered, aliases: true)

    expect(config.dig("development", "primary", "database")).to eq("talkk_api_development")
    expect(config.dig("development", "cache", "database")).to eq("talkk_api_cache_development")
    expect(config.dig("development", "queue", "database")).to eq("talkk_api_queue_development")
    expect(config.dig("development", "cable", "database")).to eq("talkk_api_cable_development")

    expect(config.dig("test", "primary", "database")).to eq("talkk_api_test")
    expect(config.dig("test", "cache", "database")).to eq("talkk_api_cache_test")
    expect(config.dig("test", "queue", "database")).to eq("talkk_api_queue_test")
    expect(config.dig("test", "cable", "database")).to eq("talkk_api_cable_test")

    expect(config.dig("staging", "primary")).to be_present
    expect(config.dig("staging", "queue")).to be_present
    expect(config.dig("staging", "cache")).to be_present
    expect(config.dig("staging", "cable")).to be_present
  end

  it "enables Solid Cache and Solid Queue in development environment config" do
    development_config = File.read(Rails.root.join("config/environments/development.rb"))

    expect(development_config).to include("config.cache_store = :solid_cache_store")
    expect(development_config).to include("config.active_job.queue_adapter = :solid_queue")
    expect(development_config).to include("config.solid_queue.connects_to = { database: { writing: :queue } }")
  end

  it "maps cache database for development and test in cache.yml" do
    rendered = ERB.new(File.read(Rails.root.join("config/cache.yml"))).result
    cache_config = YAML.safe_load(rendered, aliases: true)

    expect(cache_config.dig("development", "database")).to eq("cache")
    expect(cache_config.dig("test", "database")).to eq("cache")
    expect(cache_config.dig("production", "database")).to eq("cache")
  end

  it "includes optional Solid Queue Puma plugin" do
    puma_config = File.read(Rails.root.join("config/puma.rb"))

    expect(puma_config).to include('plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]')
  end
end
