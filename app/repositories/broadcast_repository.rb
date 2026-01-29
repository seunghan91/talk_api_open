# frozen_string_literal: true

class BroadcastRepository
  # 브로드캐스트 생성
  def create!(attributes)
    Broadcast.create!(attributes)
  end

  # ID로 브로드캐스트 찾기
  def find(id)
    Broadcast.find(id)
  end

  # ID로 브로드캐스트 찾기 (없으면 nil)
  def find_by_id(id)
    Broadcast.find_by(id: id)
  end

  # 사용자의 브로드캐스트
  def by_user(user, limit: 50)
    Broadcast.where(user: user)
             .includes(:user, broadcast_recipients: :user)
             .with_attached_audio
             .order(created_at: :desc)
             .limit(limit)
  end

  # 사용자가 받은 브로드캐스트
  def received_by_user(user, limit: 50)
    Broadcast.joins(:broadcast_recipients)
             .where(broadcast_recipients: { user_id: user.id })
             .includes(:user)
             .with_attached_audio
             .order("broadcast_recipients.created_at DESC")
             .limit(limit)
  end

  # 오늘 사용자가 보낸 브로드캐스트 수
  def count_today_by_user(user)
    Broadcast.where(user: user)
             .where("created_at >= ?", Time.current.beginning_of_day)
             .count
  end

  # 최근 활성 브로드캐스트
  def recent_active(since: 24.hours.ago, limit: 100)
    Broadcast.where("created_at > ?", since)
             .where(active: true)
             .includes(:user)
             .order(created_at: :desc)
             .limit(limit)
  end

  # 브로드캐스트에 수신자 추가
  def add_recipients(broadcast, user_ids)
    recipients = user_ids.map do |user_id|
      {
        broadcast_id: broadcast.id,
        user_id: user_id,
        status: :delivered,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    BroadcastRecipient.insert_all(recipients) if recipients.any?
  end

  # 수신자 상태 업데이트
  def update_recipient_status(broadcast_id, user_id, status)
    recipient = BroadcastRecipient.find_by(
      broadcast_id: broadcast_id,
      user_id: user_id
    )
    
    recipient&.update(status: status)
  end

  # 특정 기간 동안의 브로드캐스트 통계
  def statistics(user: nil, from: 30.days.ago, to: Time.current)
    scope = Broadcast.where(created_at: from..to)
    scope = scope.where(user: user) if user
    
    {
      total_count: scope.count,
      total_recipients: BroadcastRecipient.joins(:broadcast)
                                          .merge(scope)
                                          .count,
      replied_count: BroadcastRecipient.joins(:broadcast)
                                       .merge(scope)
                                       .where(status: :replied)
                                       .count,
      read_count: BroadcastRecipient.joins(:broadcast)
                                     .merge(scope)
                                     .where(status: :read)
                                     .count
    }
  end

  # 페이지네이션 지원
  def paginated(page: 1, per_page: 20)
    Broadcast.page(page).per(per_page)
  end

  class << self
    # 클래스 메서드로도 사용 가능
    def by_user(user, limit: 50)
      new.by_user(user, limit: limit)
    end

    def received_by_user(user, limit: 50)
      new.received_by_user(user, limit: limit)
    end

    def recent_active(since: 24.hours.ago, limit: 100)
      new.recent_active(since: since, limit: limit)
    end
  end
end
