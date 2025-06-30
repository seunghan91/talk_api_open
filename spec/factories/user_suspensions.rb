FactoryBot.define do
  factory :user_suspension do
    association :user
    reason { "Violation of terms" }
    suspended_at { Time.current }
    suspended_until { 7.days.from_now }
    active { true }
  end
end
