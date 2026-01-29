# app/events/message_sent_event.rb
class MessageSentEvent < BaseEvent
  attr_reader :message, :sender, :conversation
  
  def initialize(message:, sender:, conversation:)
    super(
      message: message,
      sender: sender,
      conversation: conversation
    )
  end
  
  def to_h
    super.merge(
      message_id: message.id,
      sender_id: sender.id,
      sender_nickname: sender.nickname,
      conversation_id: conversation.id,
      message_type: message.message_type,
      has_voice: message.voice_file.attached?,
      recipient_id: conversation.other_user(sender).id,
      sent_at: message.created_at
    )
  end
end 