FactoryBot.define do
  factory :broadcast_recipient do
    association :user
    association :broadcast
    status { :delivered }
  end
end
