# app/services/conversation_service.rb
class ConversationService
  class Result
    attr_reader :success, :conversation, :message, :error

    def initialize(success:, conversation: nil, message: nil, error: nil)
      @success = success
      @conversation = conversation
      @message = message
      @error = error
    end

    def success?
      @success
    end
  end

  def initialize(current_user)
    @current_user = current_user
  end

  # 대화 목록 조회
  def list_conversations
    conversations = Conversation
      .for_user(@current_user.id)
      .not_deleted_for(@current_user.id)
      .order(updated_at: :desc)
      .includes(:user_a, :user_b, messages: [:broadcast])

    formatted_conversations = format_conversations(conversations)
    
    Result.new(success: true, conversation: formatted_conversations)
  rescue => e
    Rails.logger.error("대화 목록 조회 오류: #{e.message}")
    Result.new(success: false, error: "대화 목록을 불러오는 데 실패했습니다.")
  end

  # 대화 상세 조회
  def show_conversation(conversation_id)
    conversation = Conversation.find(conversation_id)
    
    unless participant?(conversation)
      return Result.new(success: false, error: "권한이 없습니다.")
    end

    # 대화방을 볼 때 사용자에게 가시성 설정
    restore_visibility(conversation)

    messages = fetch_messages(conversation)
    
    Result.new(
      success: true,
      conversation: conversation,
      message: messages
    )
  rescue ActiveRecord::RecordNotFound
    Result.new(success: false, error: "대화를 찾을 수 없습니다.")
  rescue => e
    Rails.logger.error("대화 조회 오류: #{e.message}")
    Result.new(success: false, error: "대화를 불러오는 데 실패했습니다.")
  end

  # 대화 생성 또는 찾기
  def find_or_create_conversation(other_user_id, broadcast = nil)
    return Result.new(success: false, error: "자기 자신과는 대화할 수 없습니다.") if @current_user.id == other_user_id

    conversation = Conversation.find_or_create_conversation(@current_user.id, other_user_id, broadcast)
    
    if conversation&.persisted?
      Result.new(success: true, conversation: conversation)
    else
      Result.new(success: false, error: "대화 생성에 실패했습니다.")
    end
  rescue => e
    Rails.logger.error("대화 생성 오류: #{e.message}")
    Result.new(success: false, error: "대화 생성 중 오류가 발생했습니다.")
  end

  # 브로드캐스트로부터 대화 생성
  def create_from_broadcast(broadcast, recipient_id)
    conversation = Conversation.create_from_broadcast(broadcast, recipient_id)
    
    if conversation&.persisted?
      Result.new(success: true, conversation: conversation)
    else
      Result.new(success: false, error: "브로드캐스트에서 대화 생성에 실패했습니다.")
    end
  rescue => e
    Rails.logger.error("브로드캐스트 대화 생성 오류: #{e.message}")
    Result.new(success: false, error: "대화 생성 중 오류가 발생했습니다.")
  end

  # 대화 삭제 (소프트 삭제)
  def delete_conversation(conversation_id)
    conversation = Conversation.find(conversation_id)
    
    unless participant?(conversation)
      return Result.new(success: false, error: "권한이 없습니다.")
    end

    conversation.hide_from!(@current_user.id)
    
    Result.new(success: true, message: "대화방이 삭제되었습니다.")
  rescue ActiveRecord::RecordNotFound
    Result.new(success: false, error: "대화를 찾을 수 없습니다.")
  rescue => e
    Rails.logger.error("대화 삭제 오류: #{e.message}")
    Result.new(success: false, error: "대화 삭제 중 오류가 발생했습니다.")
  end

  # 즐겨찾기 토글
  def toggle_favorite(conversation_id)
    conversation = Conversation.find(conversation_id)
    
    unless participant?(conversation)
      return Result.new(success: false, error: "권한이 없습니다.")
    end

    # 즐겨찾기 상태 토글
    if @current_user.id == conversation.user_a_id
      conversation.update!(favorited_by_a: !conversation.favorited_by_a)
      favorited = conversation.favorited_by_a
    else
      conversation.update!(favorited_by_b: !conversation.favorited_by_b)
      favorited = conversation.favorited_by_b
    end

    message = favorited ? "즐겨찾기 등록 완료" : "즐겨찾기 해제 완료"
    Result.new(success: true, conversation: conversation, message: message)
  rescue ActiveRecord::RecordNotFound
    Result.new(success: false, error: "대화를 찾을 수 없습니다.")
  rescue => e
    Rails.logger.error("즐겨찾기 토글 오류: #{e.message}")
    Result.new(success: false, error: "즐겨찾기 처리 중 오류가 발생했습니다.")
  end

  # 읽지 않은 메시지 수 조회
  def unread_message_count
    conversations = Conversation
      .for_user(@current_user.id)
      .not_deleted_for(@current_user.id)

    total_unread = 0
    conversations.each do |conversation|
      last_read_at = if @current_user.id == conversation.user_a_id
                       conversation.last_read_at_a
                     else
                       conversation.last_read_at_b
                     end

      unread_count = conversation.messages
        .where("created_at > ?", last_read_at || conversation.created_at)
        .where.not(sender_id: @current_user.id)
        .count

      total_unread += unread_count
    end

    Result.new(success: true, message: total_unread)
  rescue => e
    Rails.logger.error("읽지 않은 메시지 수 조회 오류: #{e.message}")
    Result.new(success: false, error: "읽지 않은 메시지 수 조회에 실패했습니다.")
  end

  # 대화 읽음 처리
  def mark_as_read(conversation_id)
    conversation = Conversation.find(conversation_id)
    
    unless participant?(conversation)
      return Result.new(success: false, error: "권한이 없습니다.")
    end

    # 현재 시간으로 읽음 시간 업데이트
    if @current_user.id == conversation.user_a_id
      conversation.update!(last_read_at_a: Time.current)
    else
      conversation.update!(last_read_at_b: Time.current)
    end

    Result.new(success: true, message: "읽음 처리 완료")
  rescue ActiveRecord::RecordNotFound
    Result.new(success: false, error: "대화를 찾을 수 없습니다.")
  rescue => e
    Rails.logger.error("읽음 처리 오류: #{e.message}")
    Result.new(success: false, error: "읽음 처리 중 오류가 발생했습니다.")
  end

  private

  def participant?(conversation)
    [conversation.user_a_id, conversation.user_b_id].include?(@current_user.id)
  end

  def restore_visibility(conversation)
    conversation.show_to!(@current_user.id)
  end

  def fetch_messages(conversation)
    Rails.cache.fetch("conversation-messages-#{conversation.id}", expires_in: 30.seconds) do
      conversation.messages.order(created_at: :asc).includes(:sender).to_a
    end
  end

  def format_conversations(conversations)
    conversations.map do |conversation|
      other_user = (conversation.user_a_id == @current_user.id) ? conversation.user_b : conversation.user_a
      last_message = conversation.messages.max_by(&:created_at)

      next nil unless last_message

      message_content = format_message_content(last_message)

      {
        id: conversation.id,
        with_user: {
          id: other_user.id,
          nickname: other_user.nickname,
          gender: other_user.gender || "unspecified"
        },
        last_message: {
          id: last_message.id,
          content: message_content,
          created_at: last_message.created_at,
          message_type: last_message.message_type || "voice"
        },
        updated_at: conversation.updated_at,
        favorite: conversation.favorited_by?(@current_user.id),
        unread_count: calculate_unread_count(conversation)
      }
    rescue => e
      Rails.logger.error("대화 정보 변환 중 오류: #{e.message}")
      nil
    end.compact
  end

  def format_message_content(message)
    case message.message_type
    when "voice"
      "음성 메시지"
    when "text"
      message.content || "메시지"
    when "image"
      "이미지"
    else
      if message.broadcast_id.present?
        broadcast = message.broadcast
        broadcast ? "브로드캐스트: #{broadcast.content&.truncate(20) || '내용 없음'}" : "삭제된 브로드캐스트"
      else
        "메시지"
      end
    end
  end

  def calculate_unread_count(conversation)
    last_read_at = if @current_user.id == conversation.user_a_id
                     conversation.last_read_at_a
                   else
                     conversation.last_read_at_b
                   end

    conversation.messages
      .where("created_at > ?", last_read_at || conversation.created_at)
      .where.not(sender_id: @current_user.id)
      .count
  end
end