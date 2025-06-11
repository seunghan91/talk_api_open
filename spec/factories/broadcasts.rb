FactoryBot.define do
  factory :broadcast do
    audio_url { "https://example.com/audio/sample_#{rand(1..3)}.wav" }
    duration { rand(5..60) }
    private { false }

    association :user

    trait :private_broadcast do
      private { true }
    end

    trait :with_replies do
      after(:create) do |broadcast|
        create_list(:message, 2, broadcast: broadcast, sender: create(:user), receiver: broadcast.user)
      end
    end
  end
end
