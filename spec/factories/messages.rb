FactoryBot.define do
  factory :message do
    message_type { "voice" }
    duration { rand(5..60) }
    read { false }

    association :conversation
    association :sender, factory: :user

    # By default, attach a voice file for voice messages
    after(:build) do |message|
      if message.message_type == "voice" && !message.voice_file.attached?
        message.voice_file.attach(
          io: StringIO.new("fake audio content"),
          filename: "voice_message.m4a",
          content_type: "audio/m4a"
        )
      end
    end

    trait :with_broadcast do
      association :broadcast
      message_type { "broadcast_reply" }
    end

    trait :with_voice_file do
      after(:build) do |message|
        message.voice_file.attach(
          io: StringIO.new("fake audio content"),
          filename: "voice_message.m4a",
          content_type: "audio/m4a"
        )
      end
    end

    trait :read do
      read { true }
    end

    trait :unread do
      read { false }
    end
  end
end
