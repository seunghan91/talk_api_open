FactoryBot.define do
  factory :conversation do
    association :user_a, factory: :user
    association :user_b, factory: :user

    favorited_by_user_a { false }
    favorited_by_user_b { false }

    trait :favorited_by_a do
      favorited_by_user_a { true }
    end

    trait :favorited_by_b do
      favorited_by_user_b { true }
    end

    trait :with_messages do
      after(:create) do |conversation|
        create_list(:message, 3, conversation: conversation, sender: conversation.user_a, receiver: conversation.user_b)
      end
    end
  end
end
