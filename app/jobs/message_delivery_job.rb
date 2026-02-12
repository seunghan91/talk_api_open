class MessageDeliveryJob < ApplicationJob
  queue_as :messages
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    conversation = message.conversation
    receiver_id = (conversation.user_a_id == message.sender_id) ? conversation.user_b_id : conversation.user_a_id
    receiver = User.find_by(id: receiver_id)

    return unless receiver

    # 푸시 알림 잡 호출
    PushNotificationJob.perform_later("message", message_id)

    # 메시지 처리 완료 후 상태 업데이트
    message.update(processed: true) if message.respond_to?(:processed)

    # 대화 업데이트 시간 갱신
    conversation.touch

    # 로깅
    Rails.logger.info("메시지 전송 완료: ID #{message_id}, 수신자 ID #{receiver_id}")
  end
end
