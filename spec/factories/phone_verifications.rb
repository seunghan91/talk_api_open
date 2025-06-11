FactoryBot.define do
  factory :phone_verification do
    phone_number { "010#{rand(1000..9999)}#{rand(1000..9999)}" }
    code { rand(100000..999999).to_s }
    expires_at { 5.minutes.from_now }
    verified { false }

    association :user, factory: :user, optional: true

    trait :verified do
      verified { true }
    end

    trait :expired do
      expires_at { 5.minutes.ago }
    end
  end
end
