# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: 'User', foreign_key: :sender_id
  
  has_one_attached :voice_file
  has_one_attached :image_file

  validates :content, presence: true, unless: -> { message_type == 'voice' || message_type == 'image' }
  validates :message_type, inclusion: { in: ['text', 'voice', 'image'] }

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
  
  # 음성 또는 이미지 파일이 첨부된 메시지 체크
  def has_attachment?
    voice_file.attached? || image_file.attached?
  end
  
  # 메시지 타입에 따라 적절한 첨부 파일 체크
  def valid_attachment?
    return true if message_type == 'text'
    return voice_file.attached? if message_type == 'voice'
    return image_file.attached? if message_type == 'image'
    false
  end
  
  private
  
  # 첨부파일 타입 검증
  def validate_file_type
    if message_type == 'voice' && voice_file.attached?
      unless voice_file.content_type.in?(%w[audio/m4a audio/mp4 audio/mpeg audio/aac audio/wav audio/webm])
        errors.add(:voice_file, '유효한 오디오 파일이 아닙니다.')
      end
    elsif message_type == 'image' && image_file.attached?
      unless image_file.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
        errors.add(:image_file, '유효한 이미지 파일이 아닙니다.')
      end
    end
  end

  # RailsAdmin 설정 (rails_admin gem이 활성화된 경우에만 사용)
  # rails_admin do
  #   list do
  #     field :id
  #     field :conversation
  #     field :sender
  #     field :created_at
  #     field :voice_file
  #     field :is_read
  #   end
  #   
  #   show do
  #     field :id
  #     field :conversation
  #     field :sender
  #     field :created_at
  #     field :updated_at
  #     field :voice_file
  #     field :is_read
  #   end
  #   
  #   edit do
  #     field :conversation
  #     field :sender
  #     field :is_read
  #   end
  # end
end