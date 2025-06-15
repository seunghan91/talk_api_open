# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: "User", foreign_key: "sender_id"
  belongs_to :broadcast, optional: true

  # 파일 첨부 기능 활성화
  has_one_attached :voice_file

  # 음성 파일 변경 시 duration 설정 콜백 추가
  after_save :set_duration_from_voice_file, if: -> { voice_file.attached? && saved_change_to_voice_file_attachment? }

  # 메시지 타입 검증 - voice, broadcast, text 허용
  validates :message_type, presence: true,
            inclusion: { in: %w[text voice broadcast_reply] }
  validates :sender_id, presence: true

  # 음성 메시지일 경우 voice_file 필수 (시드 데이터 생성을 위해 일시적으로 주석 처리)
  # validates :voice_file, presence: true, if: -> { message_type == 'voice' && !broadcast_id.present? }

  # 파일 타입 검증
  validate :validate_voice_file_type, if: -> { voice_file.attached? }

  # 메시지 생성 후 처리
  after_create :process_message

  # 음성 파일이 첨부된 메시지 체크
  def has_attachment?
    voice_file.attached?
  end

  # 메시지 타입에 따라 적절한 첨부 파일 체크
  def valid_attachment?
    voice_file.attached?
  end

  # 컬렉션에서 중복된 메시지 제거
  scope :unique_by_broadcast, -> { select("DISTINCT ON (broadcast_id) *").where.not(broadcast_id: nil) }

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
    update(is_read: true, read_at: Time.current)
  end

  # 메시지 삭제 처리 (실제 삭제는 수행하지 않고 삭제 플래그만 설정)
  def soft_delete_for_user!(user_id)
    # 대화 내에서 user_a인지 user_b인지 확인
    if conversation.user_a_id == user_id
      update(deleted_by_a: true)
    elsif conversation.user_b_id == user_id
      update(deleted_by_b: true)
    end

    # 양쪽 모두 삭제 처리된 경우 실제 삭제
    destroy if deleted_by_a && deleted_by_b
  end

  # 메시지 내용 요약 (미리보기용)
  def preview
    if voice_file.attached?
      "음성 메시지"
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
    if conversation.user_a_id == user_id
      !deleted_by_a
    elsif conversation.user_b_id == user_id
      !deleted_by_b
    else
      false
    end
  end

  # 수신자 찾기
  def receiver
    if conversation.user_a_id == sender_id
      conversation.user_b
    else
      conversation.user_a
    end
  end

  private

  # 메시지 생성 후 처리 (푸시 알림 등)
  def process_message
    # 상대방에게 푸시 알림 전송
    recipient_id = get_recipient_id
    # 여기에 푸시 알림 로직이 들어갈 수 있습니다
    Rails.logger.info("메시지 생성 완료: ID #{id}, 수신자 ID: #{recipient_id}, 메시지 타입: #{message_type}, 브로드캐스트 ID: #{broadcast_id}")

    # 대화 마지막 업데이트 시간 갱신
    conversation.touch

    # 메시지 전송 후 알림 생성
    create_notification
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
  def validate_voice_file_type
    unless voice_file.content_type.in?(%w[audio/m4a audio/mp4 audio/mpeg audio/aac audio/wav audio/webm audio/x-m4a])
      errors.add(:voice_file, "유효한 오디오 파일이 아닙니다.")
    end
  end

  # 음성 파일에서 재생 시간(duration) 설정
  def set_duration_from_voice_file
    return unless voice_file.attached?

    begin
      # 음성 파일 정보 추출
      audio_info = AudioProcessorService.get_audio_info(voice_file.blob.service.path_for(voice_file.key))

      if audio_info && audio_info[:duration]
        # 반올림하여 정수로 저장 (초 단위)
        update_column(:duration, audio_info[:duration].round)
        Rails.logger.info("메시지 ID #{id}의 duration 값을 #{duration}초로 설정")
      else
        Rails.logger.warn("메시지 ID #{id}의 음성 파일에서 duration을 추출할 수 없음")
      end
    rescue => e
      # 오류가 발생해도 메시지 저장 자체는 실패하지 않도록 로그만 남김
      Rails.logger.error("메시지 ID #{id}의 duration 설정 중 오류 발생: #{e.message}")
    end
  end

  def create_notification
    # 수신자에게 알림 생성
    return unless receiver.present?
    
    notification = Notification.create!(
      user: receiver,
      notification_type: 'message',
      title: '새 메시지',
      body: "#{sender.nickname}님이 메시지를 보냈습니다",
      notifiable: self,
      metadata: {
        sender_id: sender.id,
        sender_nickname: sender.nickname,
        conversation_id: conversation.id,
        message_type: message_type
      }
    )
    
    # 백그라운드 작업으로 푸시 알림 전송
    if receiver.push_enabled && receiver.message_push_enabled && receiver.push_token.present?
      PushNotificationWorker.perform_async('message', id)
    end
  rescue => e
    Rails.logger.error "알림 생성 실패: #{e.message}"
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
