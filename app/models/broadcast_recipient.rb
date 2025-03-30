# app/models/broadcast_recipient.rb
class BroadcastRecipient < ApplicationRecord
  belongs_to :broadcast
  belongs_to :user

  # 상태 enum (delivered: 전달됨, read: 읽음, replied: 답장됨)
  enum status: { delivered: 0, read: 1, replied: 2 }

  # after_create 콜백 제거 - BroadcastWorker에서 처리하도록 변경
  # (중복 대화/메시지 생성 방지)
  
  # 이 브로드캐스트 수신자의 대화 찾기
  def find_conversation
    Conversation.where(
      user_a_id: [broadcast.user_id, user_id].min,
      user_b_id: [broadcast.user_id, user_id].max
    ).first
  end
  
  # 대화 존재 여부 확인
  def conversation_exists?
    find_conversation.present?
  end
end 