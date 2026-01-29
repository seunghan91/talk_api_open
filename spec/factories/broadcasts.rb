FactoryBot.define do
  factory :broadcast do
    association :user
    content { "This is a sample broadcast content." }
    duration { rand(5..60) }

    trait :with_replies do
      after(:create) do |broadcast|
        conversation = create(:conversation, user_a: broadcast.user, user_b: create(:user))
        create_list(:message, 2, broadcast: broadcast, sender: conversation.user_b, conversation: conversation)
      end
    end
  end
end
