FactoryBot.define do
  factory :conversation do
    association :user_a, factory: :user
    association :user_b, factory: :user

    favorited_by_a { false }
    favorited_by_b { false }
    deleted_by_a { false }
    deleted_by_b { false }

    trait :favorited_by_a do
      favorited_by_a { true }
    end

    trait :favorited_by_b do
      favorited_by_b { true }
    end

    trait :with_messages do
      after(:create) do |conversation|
        create_list(:message, 3, conversation: conversation, sender: conversation.user_a)
      end
    end
  end
end
