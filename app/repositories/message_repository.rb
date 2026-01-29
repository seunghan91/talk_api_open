# app/repositories/message_repository.rb
class MessageRepository
  # 메시지 생성
  def create!(attributes)
    Message.create!(attributes)
  end

  # ID로 메시지 찾기
  def find(id)
    Message.find(id)
  end

  # ID로 메시지 찾기 (없으면 nil)
  def find_by_id(id)
    Message.find_by(id: id)
  end

  # 대화의 메시지들
  def by_conversation(conversation, limit: 50)
    Message.where(conversation: conversation)
           .includes(:sender)
           .with_attached_voice_file
           .order(created_at: :desc)
           .limit(limit)
  end

  # 사용자가 보낸 메시지들
  def sent_by_user(user, limit: 50)
    Message.where(sender: user)
           .includes(:conversation)
           .order(created_at: :desc)
           .limit(limit)
  end

  # 읽지 않은 메시지들
  def unread_for_user(user)
    Message.joins(:conversation)
           .where(read: false)
           .where.not(sender: user)
           .where(
             "(conversations.user_a_id = :user_id OR conversations.user_b_id = :user_id)",
             user_id: user.id
           )
  end

  # 메시지 읽음 처리
  def mark_as_read(message_ids)
    Message.where(id: message_ids, read: false)
           .update_all(read: true, updated_at: Time.current)
  end

  # 대화의 마지막 메시지
  def last_message_for_conversation(conversation)
    Message.where(conversation: conversation)
           .order(created_at: :desc)
           .first
  end

  # 메시지 삭제 (소프트 삭제)
  def soft_delete_for_user(message, user)
    if message.conversation.user_a_id == user.id
      message.update(deleted_by_a: true)
    elsif message.conversation.user_b_id == user.id
      message.update(deleted_by_b: true)
    end
  end

  # 메시지 통계
  def statistics(user: nil, from: 30.days.ago, to: Time.current)
    scope = Message.where(created_at: from..to)
    scope = scope.where(sender: user) if user
    
    {
      total_count: scope.count,
      voice_count: scope.where(message_type: 'voice').count,
      text_count: scope.where(message_type: 'text').count,
      read_count: scope.where(read: true).count,
      unread_count: scope.where(read: false).count
    }
  end

  # 브로드캐스트 답장 메시지들
  def broadcast_replies(broadcast)
    Message.where(broadcast_id: broadcast.id)
           .includes(:sender, :conversation)
           .order(created_at: :desc)
  end

  # 메시지 검색
  def search(query, user: nil)
    scope = Message.where("text LIKE ?", "%#{query}%")
    
    if user
      scope = scope.joins(:conversation)
                   .where(
                     "(conversations.user_a_id = :user_id OR conversations.user_b_id = :user_id)",
                     user_id: user.id
                   )
    end
    
    scope.includes(:sender, :conversation)
         .order(created_at: :desc)
  end

  # 페이지네이션 지원
  def paginated(page: 1, per_page: 20)
    Message.page(page).per(per_page)
  end

  class << self
    # 클래스 메서드로도 사용 가능
    def by_conversation(conversation, limit: 50)
      new.by_conversation(conversation, limit: limit)
    end

    def unread_for_user(user)
      new.unread_for_user(user)
    end

    def last_message_for_conversation(conversation)
      new.last_message_for_conversation(conversation)
    end
  end
end 