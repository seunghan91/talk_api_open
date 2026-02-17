FactoryBot.define do
  factory :broadcast_usage_log do
    association :user
    date { Date.current }
    broadcasts_sent { 0 }
    last_broadcast_at { nil }
    limit_exceeded_count { 0 }

    trait :with_usage do
      broadcasts_sent { 5 }
      last_broadcast_at { 30.minutes.ago }
    end

    trait :at_daily_limit do
      broadcasts_sent { 20 }
      last_broadcast_at { 5.minutes.ago }
    end

    trait :with_exceeded_attempts do
      broadcasts_sent { 20 }
      last_broadcast_at { 5.minutes.ago }
      limit_exceeded_count { 3 }
    end
  end
end
