FactoryBot.define do
  factory :session do
    user
    ip_address { "127.0.0.1" }
    user_agent { "RSpec Test Agent" }
    last_active_at { Time.current }

    trait :expired do
      last_active_at { 31.days.ago }
    end

    trait :active do
      last_active_at { 1.day.ago }
    end

    trait :boundary do
      last_active_at { 30.days.ago }
    end
  end
end
