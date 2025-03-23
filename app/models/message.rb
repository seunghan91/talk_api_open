# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: "User"
  belongs_to :broadcast, optional: true

  # 파일 첨부 기능 활성화
  has_one_attached :voice_file
  has_one_attached :image_file

  # message_type은 voice가 기본값
  validates :message_type, inclusion: { in: [ "voice", "text", "image" ] }

  # 텍스트 메시지일 경우에만 content 필수
  validates :content, presence: true, if: -> { message_type == "text" }

  # 음성 메시지일 경우 voice_file 필수
  validates :voice_file, presence: true, if: -> { message_type == "voice" }

  # 이미지 메시지일 경우 image_file 필수
  validates :image_file, presence: true, if: -> { message_type == "image" }

  # 파일 타입 검증
  validate :validate_file_type, if: -> { voice_file.attached? || image_file.attached? }

  # 메시지 생성 후 처리
  after_create :process_message

  # 음성 또는 이미지 파일이 첨부된 메시지 체크
  def has_attachment?
    voice_file.attached? || image_file.attached?
  end

  # 메시지 타입에 따라 적절한 첨부 파일 체크
  def valid_attachment?
    return content.present? if message_type == "text"
    return voice_file.attached? if message_type == "voice"
    return image_file.attached? if message_type == "image"
    false
  end

  # 컬렉션에서 중복된 메시지 제거
  scope :unique_by_broadcast, -> { select('DISTINCT ON (broadcast_id) *').where.not(broadcast_id: nil) }

  # 브로드캐스트 관련 메시지인지 확인
  def broadcast?
    broadcast_id.present?
  end

  # 메시지가 읽혔는지 확인
  def read?
    read_at.present?
  end

  # 메시지 읽음 처리
  def mark_as_read!
    return if read?
    update(read_at: Time.current)
  end

  # 메시지 삭제 처리 (실제 삭제는 수행하지 않고 삭제 플래그만 설정)
  def soft_delete_for_user!(user_id)
    if sender_id == user_id
      update(deleted_by_sender: true)
    else
      update(deleted_by_recipient: true)
    end
    
    # 양쪽 모두 삭제 처리된 경우 실제 삭제
    destroy if deleted_by_sender && deleted_by_recipient
  end

  # 메시지 내용 요약 (미리보기용)
  def preview
    if voice_file.attached?
      "음성 메시지"
    elsif text.present?
      text.truncate(30)
    elsif broadcast.present?
      "브로드캐스트 메시지"
    else
      "내용 없음"
    end
  end

  # 음성 파일 URL
  def voice_url
    voice_file.attached? ? voice_file.url : nil
  end

  # 브로드캐스트 메시지인 경우 음성 파일 URL 반환
  def broadcast_voice_url
    return nil unless broadcast
    broadcast.voice_file.attached? ? broadcast.voice_file.url : nil
  end
  
  # 사용자가 메시지를 볼 수 있는지 확인
  def visible_to?(user_id)
    if sender_id == user_id
      !deleted_by_sender
    else
      !deleted_by_recipient
    end
  end

  private

  # 메시지 생성 후 처리 (푸시 알림 등)
  def process_message
    # 상대방에게 푸시 알림 전송
    recipient_id = get_recipient_id
    # 여기에 푸시 알림 로직이 들어갈 수 있습니다
    Rails.logger.info("메시지 생성 완료: ID #{id}, 수신자 ID: #{recipient_id}")
  end

  # 수신자 ID 찾기
  def get_recipient_id
    if conversation.user_a_id == sender_id
      conversation.user_b_id
    else
      conversation.user_a_id
    end
  end

  # 첨부파일 타입 검증
  def validate_file_type
    if message_type == "voice" && voice_file.attached?
      unless voice_file.content_type.in?(%w[audio/m4a audio/mp4 audio/mpeg audio/aac audio/wav audio/webm audio/x-m4a])
        errors.add(:voice_file, "유효한 오디오 파일이 아닙니다.")
      end
    elsif message_type == "image" && image_file.attached?
      unless image_file.content_type.in?(%w[image/jpeg image/png image/gif image/webp])
        errors.add(:image_file, "유효한 이미지 파일이 아닙니다.")
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
