FactoryBot.define do
  factory :report do
    association :reporter, factory: :user
    association :reported, factory: :user
    reason { 'spam' }
    status { 'pending' }
    report_type { 'user' }
  end
end
