FactoryBot.define do
  factory :message do
    audio_url { "https://example.com/audio/sample_#{rand(1..3)}.wav" }
    message_type { "voice" }
    duration { rand(5..60) }
    
    association :conversation
    association :sender, factory: :user
    association :receiver, factory: :user
    association :broadcast, factory: :broadcast, optional: true
    
    trait :with_broadcast do
      association :broadcast
    end
  end
end 