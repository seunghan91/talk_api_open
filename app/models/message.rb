# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: 'User', foreign_key: :sender_id
  
  has_one_attached :voice_file

  # 1) 메시지 생성 직후에 Sidekiq 작업(푸시 알림 전송)을 등록
  after_create :enqueue_push_job

  def enqueue_push_job
    # 2) 이 메서드에서 Worker에 메시지 ID를 넘김
    PushNotificationWorker.perform_async(id)
  end

  # 3) 실제 푸시 발송 로직 (Worker에서 호출)
  def send_push_notification
    # 예: 대화 상대 찾기
    recipient_id = (conversation.user_a_id == sender_id ? conversation.user_b_id : conversation.user_a_id)
    recipient = User.find(recipient_id)
    return unless recipient.push_token.present?

    # 예시: Expo Push API 호출 로직
    ExponentPushNotifier.send_message(
      to: recipient.push_token,
      title: "새 메시지 도착",
      body: "#{sender.nickname}님이 메시지를 보냈습니다."
    )
  end
  
  # RailsAdmin 설정
  rails_admin do
    list do
      field :id
      field :conversation
      field :sender
      field :created_at
      field :voice_file
      field :is_read
    end
    
    show do
      field :id
      field :conversation
      field :sender
      field :created_at
      field :updated_at
      field :voice_file
      field :is_read
    end
    
    edit do
      field :conversation
      field :sender
      field :is_read
    end
  end
end