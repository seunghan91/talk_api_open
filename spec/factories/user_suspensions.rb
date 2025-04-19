FactoryBot.define do
  factory :user_suspension do
    user { nil }
    reason { "MyString" }
    suspended_at { "2025-04-19 12:04:15" }
    suspended_until { "2025-04-19 12:04:15" }
    suspended_by { "MyString" }
  end
end
