# app/models/broadcast_recipient.rb
class BroadcastRecipient < ApplicationRecord
  belongs_to :broadcast
  belongs_to :user

  # 상태 enum (delivered: 전달됨, read: 읽음, replied: 답장됨)
  enum status: { delivered: 0, read: 1, replied: 2 }

  # 브로드캐스트 수신 시 자동으로 대화 생성
  after_create :ensure_conversation_exists

  private

  # 브로드캐스트 발신자와 수신자 간의 대화 생성 또는 찾기
  def ensure_conversation_exists
    # 이미 존재하는 대화 찾기
    conversation = Conversation.find_or_create_by(
      user_a_id: [broadcast.user_id, user_id].min,
      user_b_id: [broadcast.user_id, user_id].max
    )

    # 대화의 상태를 활성화
    if conversation.persisted?
      # 삭제 플래그 초기화
      if conversation.user_a_id == broadcast.user_id
        conversation.update(deleted_by_a: false)
      else
        conversation.update(deleted_by_b: false)
      end

      # 브로드캐스트를 대화의 첫 메시지로 추가
      Message.find_or_create_by(
        conversation: conversation,
        sender_id: broadcast.user_id,
        broadcast_id: broadcast.id
      )
    end
  end
end 