FactoryBot.define do
  factory :notification do
    title { "알림 제목" }
    body { "알림 내용입니다." }
    notification_type { %w[broadcast message system].sample }
    read { false }
    metadata { {} }

    association :user

    trait :broadcast_notification do
      notification_type { "broadcast" }
      metadata do
        {
          broadcast_id: create(:broadcast).id,
          sender_nickname: "방송 보낸 사람"
        }
      end
    end

    trait :message_notification do
      notification_type { "message" }
      metadata do
        {
          conversation_id: create(:conversation).id,
          sender_nickname: "메시지 보낸 사람"
        }
      end
    end

    trait :read do
      read { true }
    end
  end
end
