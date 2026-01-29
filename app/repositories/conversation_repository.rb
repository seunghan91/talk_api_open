# app/repositories/conversation_repository.rb
class ConversationRepository
  # 대화 생성
  def create!(attributes)
    Conversation.create!(attributes)
  end

  # ID로 대화 찾기
  def find(id)
    Conversation.find(id)
  end

  # ID로 대화 찾기 (없으면 nil)
  def find_by_id(id)
    Conversation.find_by(id: id)
  end

  # 사용자의 대화 목록
  def for_user(user, include_deleted: false)
    conversations = Conversation.where(
      "(user_a_id = :user_id OR user_b_id = :user_id)",
      user_id: user.id
    )
    
    unless include_deleted
      conversations = conversations.where(
        "(user_a_id = :user_id AND (deleted_by_a = false OR deleted_by_a IS NULL)) OR " +
        "(user_b_id = :user_id AND (deleted_by_b = false OR deleted_by_b IS NULL))",
        user_id: user.id
      )
    end
    
    conversations.includes(:user_a, :user_b, :messages)
                 .order(updated_at: :desc)
  end

  # 두 사용자 간의 대화 찾기
  def between_users(user1_id, user2_id)
    Conversation.where(
      "(user_a_id = :user1 AND user_b_id = :user2) OR (user_a_id = :user2 AND user_b_id = :user1)",
      user1: user1_id,
      user2: user2_id
    ).first
  end

  # 대화 찾기 또는 생성
  def find_or_create_between(user1_id, user2_id)
    conversation = between_users(user1_id, user2_id)
    
    unless conversation
      # user_a_id가 항상 더 작은 ID가 되도록 정렬
      user_a_id, user_b_id = [user1_id, user2_id].sort
      
      conversation = create!(
        user_a_id: user_a_id,
        user_b_id: user_b_id
      )
    end
    
    conversation
  end

  # 즐겨찾기한 대화들
  def favorited_by_user(user)
    conversations = for_user(user)
    
    if user.id == conversations.first&.user_a_id
      conversations.where(favorited_by_a: true)
    else
      conversations.where(favorited_by_b: true)
    end
  end

  # 읽지 않은 메시지가 있는 대화들
  def with_unread_messages(user)
    for_user(user)
      .joins(:messages)
      .where(messages: { read: false })
      .where.not(messages: { sender_id: user.id })
      .distinct
  end

  # 대화 삭제 (소프트 삭제)
  def soft_delete_for_user(conversation, user)
    if conversation.user_a_id == user.id
      conversation.update(deleted_by_a: true)
    elsif conversation.user_b_id == user.id
      conversation.update(deleted_by_b: true)
    end
  end

  # 대화 복원
  def restore_for_user(conversation, user)
    if conversation.user_a_id == user.id
      conversation.update(deleted_by_a: false)
    elsif conversation.user_b_id == user.id
      conversation.update(deleted_by_b: false)
    end
  end

  # 즐겨찾기 토글
  def toggle_favorite(conversation, user)
    if conversation.user_a_id == user.id
      conversation.update(favorited_by_a: !conversation.favorited_by_a)
    elsif conversation.user_b_id == user.id
      conversation.update(favorited_by_b: !conversation.favorited_by_b)
    end
  end

  # 대화 통계
  def statistics(user: nil)
    scope = user ? for_user(user) : Conversation.all
    
    {
      total_count: scope.count,
      active_count: scope.joins(:messages)
                        .where("messages.created_at > ?", 7.days.ago)
                        .distinct
                        .count,
      favorited_count: user ? favorited_by_user(user).count : 0,
      with_unread_count: user ? with_unread_messages(user).count : 0
    }
  end

  # 최근 활동이 있는 대화들
  def recently_active(limit: 10, since: 24.hours.ago)
    Conversation.joins(:messages)
                .where("messages.created_at > ?", since)
                .group("conversations.id")
                .order("MAX(messages.created_at) DESC")
                .limit(limit)
  end

  # 브로드캐스트 ID로 대화 찾기
  def by_broadcast(broadcast_id)
    Conversation.where(broadcast_id: broadcast_id)
  end

  class << self
    # 클래스 메서드로도 사용 가능
    def for_user(user, include_deleted: false)
      new.for_user(user, include_deleted: include_deleted)
    end

    def between_users(user1_id, user2_id)
      new.between_users(user1_id, user2_id)
    end

    def find_or_create_between(user1_id, user2_id)
      new.find_or_create_between(user1_id, user2_id)
    end
  end
end 