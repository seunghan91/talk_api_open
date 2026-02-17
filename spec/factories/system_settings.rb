FactoryBot.define do
  factory :system_setting do
    setting_key { "test_setting_#{SecureRandom.hex(4)}" }
    setting_value { { "key" => "value" } }
    description { "Test setting" }
    is_active { true }

    trait :broadcast_limits do
      setting_key { "broadcast_limits" }
      setting_value do
        {
          "daily_limit" => 20,
          "hourly_limit" => 5,
          "cooldown_minutes" => 10,
          "bypass_roles" => ["admin"]
        }
      end
      description { "Broadcast rate limiting configuration" }
    end

    trait :strict_limits do
      setting_key { "broadcast_limits" }
      setting_value do
        {
          "daily_limit" => 3,
          "hourly_limit" => 2,
          "cooldown_minutes" => 5,
          "bypass_roles" => ["admin"]
        }
      end
      description { "Strict broadcast rate limiting for testing" }
    end

    trait :no_cooldown do
      setting_key { "broadcast_limits" }
      setting_value do
        {
          "daily_limit" => 20,
          "hourly_limit" => 5,
          "cooldown_minutes" => 0,
          "bypass_roles" => ["admin"]
        }
      end
      description { "Broadcast limits without cooldown" }
    end
  end
end
