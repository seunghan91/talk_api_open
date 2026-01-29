# app/events/broadcast_created_event.rb
class BroadcastCreatedEvent < BaseEvent
  attr_reader :broadcast, :sender, :recipient_count
  
  def initialize(broadcast:, sender:, recipient_count:)
    super(
      broadcast: broadcast,
      sender: sender,
      recipient_count: recipient_count
    )
  end
  
  def to_h
    super.merge(
      broadcast_id: broadcast.id,
      sender_id: sender.id,
      sender_nickname: sender.nickname,
      recipient_count: recipient_count,
      content: broadcast.content,
      has_audio: broadcast.audio.attached?,
      created_at: broadcast.created_at
    )
  end
end 