# app/services/message_service.rb
class MessageService
  class Result
    attr_reader :success, :message, :error

    def initialize(success:, message: nil, error: nil)
      @success = success
      @message = message
      @error = error
    end

    def success?
      @success
    end
  end

  def initialize(current_user)
    @current_user = current_user
    @conversation_service = ConversationService.new(current_user)
  end

  # 메시지 전송
  def send_message(conversation_id, params)
    conversation = Conversation.find(conversation_id)
    
    # 대화방 참여자 확인
    unless participant?(conversation)
      return Result.new(success: false, error: "권한이 없습니다.")
    end

    # 대화방 가시성 복원
    restore_visibility(conversation)

    # 메시지 타입 확인
    message_type = params[:message_type] || "voice"
    
    # 메시지 생성
    message = build_message(conversation, message_type, params)

    # Check if build_message already added errors (e.g., invalid file type)
    # Note: calling message.valid? clears existing errors, so check first
    if message.errors.any?
      return Result.new(
        success: false,
        error: message.errors.full_messages.join(", ")
      )
    end

    if message.valid?
      message.save!
      invalidate_caches(conversation)

      Result.new(
        success: true,
        message: format_message(message)
      )
    else
      Result.new(
        success: false,
        error: message.errors.full_messages.join(", ")
      )
    end
  rescue ActiveRecord::RecordNotFound
    Result.new(success: false, error: "대화를 찾을 수 없습니다.")
  rescue => e
    Rails.logger.error("메시지 전송 오류: #{e.message}")
    Result.new(success: false, error: "메시지 전송 중 오류가 발생했습니다.")
  end

  # 브로드캐스트 답장
  def reply_to_broadcast(broadcast_id, params)
    broadcast = Broadcast.find(broadcast_id)
    
    # 브로드캐스트 수신자 확인
    unless broadcast_recipient?(broadcast)
      return Result.new(success: false, error: "권한이 없습니다.")
    end

    # 브로드캐스트 발신자와의 대화 찾기 또는 생성
    conversation_result = @conversation_service.find_or_create_conversation(broadcast.user_id, broadcast)
    
    unless conversation_result.success?
      return conversation_result
    end

    conversation = conversation_result.conversation
    
    # 답장 메시지 생성 - broadcast_reply 타입 사용
    message_params = params.merge(
      message_type: "broadcast_reply",
      broadcast_id: broadcast.id
    )
    
    result = send_message(conversation.id, message_params)
    
    # conversation_id 추가
    if result.success?
      result.message[:conversation_id] = conversation.id
    end
    
    result
  rescue ActiveRecord::RecordNotFound
    Result.new(success: false, error: "브로드캐스트를 찾을 수 없습니다.")
  rescue => e
    Rails.logger.error("브로드캐스트 답장 오류: #{e.message}")
    Result.new(success: false, error: "답장 전송 중 오류가 발생했습니다.")
  end

  # 메시지 목록 조회
  def list_messages(conversation_id, params = {})
    conversation = Conversation.find(conversation_id)
    
    unless participant?(conversation)
      return Result.new(success: false, error: "권한이 없습니다.")
    end

    # 페이지네이션 파라미터
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    
    messages = conversation.messages
      .includes(:sender, :broadcast)
      .order(created_at: :desc)
      .page(page)
      .per(per_page)
    
    # 읽음 처리
    mark_messages_as_read(messages)
    
    Result.new(
      success: true,
      message: format_messages(messages)
    )
  rescue ActiveRecord::RecordNotFound
    Result.new(success: false, error: "대화를 찾을 수 없습니다.")
  rescue => e
    Rails.logger.error("메시지 목록 조회 오류: #{e.message}")
    Result.new(success: false, error: "메시지 목록 조회 중 오류가 발생했습니다.")
  end

  # 메시지 삭제 (소프트 삭제)
  def delete_message(message_id)
    message = Message.find(message_id)
    
    unless message.sender_id == @current_user.id
      return Result.new(success: false, error: "권한이 없습니다.")
    end

    message.soft_delete_for_user!(@current_user.id)
    
    Result.new(success: true, message: "메시지가 삭제되었습니다.")
  rescue ActiveRecord::RecordNotFound
    Result.new(success: false, error: "메시지를 찾을 수 없습니다.")
  rescue => e
    Rails.logger.error("메시지 삭제 오류: #{e.message}")
    Result.new(success: false, error: "메시지 삭제 중 오류가 발생했습니다.")
  end

  # 메시지 읽음 처리
  def mark_as_read(message_ids)
    messages = Message.where(id: message_ids)
      .joins(:conversation)
      .where("conversations.user_a_id = ? OR conversations.user_b_id = ?", @current_user.id, @current_user.id)
      .where.not(sender_id: @current_user.id)
    
    messages.update_all(read: true)
    
    Result.new(success: true, message: "#{messages.count}개 메시지를 읽음 처리했습니다.")
  rescue => e
    Rails.logger.error("읽음 처리 오류: #{e.message}")
    Result.new(success: false, error: "읽음 처리 중 오류가 발생했습니다.")
  end

  private

  def participant?(conversation)
    [conversation.user_a_id, conversation.user_b_id].include?(@current_user.id)
  end

  def broadcast_recipient?(broadcast)
    broadcast.broadcast_recipients.exists?(user_id: @current_user.id)
  end

  def restore_visibility(conversation)
    conversation.show_to!(@current_user.id)
  end

  def build_message(conversation, message_type, params)
    message = conversation.messages.new(
      sender_id: @current_user.id,
      message_type: message_type
    )

    case message_type
    when "voice"
      attach_voice_file(message, params[:voice_file])
    when "text"
      # Text messages are supported by message_type but don't have a content column
      # Voice file is optional for text type
      attach_voice_file(message, params[:voice_file]) if params[:voice_file]
    when "broadcast_reply"
      message.broadcast_id = params[:broadcast_id]
      attach_voice_file(message, params[:voice_file]) if params[:voice_file]
    end

    message
  end

  def attach_voice_file(message, voice_file)
    return unless voice_file

    unless valid_audio_file?(voice_file)
      message.errors.add(:voice_file, "유효한 오디오 파일이 아닙니다.")
      return
    end

    message.voice_file.attach(voice_file)
  end

  def valid_audio_file?(file)
    return false unless file

    valid_types = %w[audio/m4a audio/mp4 audio/mpeg audio/aac audio/wav audio/webm audio/x-m4a audio/x-wav]
    valid_types.include?(file.content_type)
  end

  def invalidate_caches(conversation)
    # 대화 메시지 캐시 무효화
    Rails.cache.delete("conversation-messages-#{conversation.id}")
    
    # 양쪽 사용자의 대화 목록 캐시 무효화
    Rails.cache.delete("conversations-user-#{conversation.user_a_id}")
    Rails.cache.delete("conversations-user-#{conversation.user_b_id}")
  end

  def mark_messages_as_read(messages)
    unread_messages = messages.select { |m| !m.read? && m.sender_id != @current_user.id }
    unread_messages.each(&:mark_as_read!)
  end

  def format_message(message)
    {
      id: message.id,
      conversation_id: message.conversation_id,
      sender: {
        id: message.sender.id,
        nickname: message.sender.nickname
      },
      message_type: message.message_type,
      voice_url: message.voice_url,
      broadcast_voice_url: message.broadcast_voice_url,
      duration: message.duration,
      read: message.read?,
      created_at: message.created_at,
      updated_at: message.updated_at
    }
  end

  def format_messages(messages)
    messages.map { |message| format_message(message) }
  end
end