# frozen_string_literal: true

class BroadcastRepository
  class << self
    def find_with_details(id)
      Broadcast.includes(:user, :conversations, :recipients).find(id)
    end
    
    def active_broadcasts
      Broadcast.where(status: :active)
    end
    
    def recent_broadcasts(limit: 20, since: nil)
      query = Broadcast.includes(:user)
      query = query.where("created_at > ?", since) if since
      query.order(created_at: :desc).limit(limit)
    end
    
    def by_user(user_id)
      Broadcast.where(user_id: user_id)
    end
    
    def with_audio
      Broadcast.where.not(audio_url: nil)
    end
    
    def by_status(status)
      Broadcast.where(status: status)
    end
    
    def search(conditions = {})
      query = Broadcast.all
      
      # 상태 필터
      if conditions[:status].present?
        query = query.where(status: conditions[:status])
      end
      
      # 날짜 범위 필터
      if conditions[:from_date].present?
        query = query.where("created_at >= ?", conditions[:from_date])
      end
      
      if conditions[:to_date].present?
        query = query.where("created_at <= ?", conditions[:to_date])
      end
      
      # 사용자 필터
      if conditions[:user_id].present?
        query = query.where(user_id: conditions[:user_id])
      end
      
      # 오디오 유무
      if conditions[:has_audio] == true
        query = query.where.not(audio_url: nil)
      elsif conditions[:has_audio] == false
        query = query.where(audio_url: nil)
      end
      
      query
    end
    
    def with_recipients_count
      Broadcast.left_joins(:broadcast_recipients)
               .group("broadcasts.id")
               .select("broadcasts.*, COUNT(broadcast_recipients.id) as recipients_count")
    end
    
    def with_conversations_count
      Broadcast.left_joins(:conversations)
               .group("broadcasts.id")
               .select("broadcasts.*, COUNT(conversations.id) as conversations_count")
    end
    
    def popular_broadcasts(threshold: 5, limit: 10)
      with_conversations_count
        .having("COUNT(conversations.id) >= ?", threshold)
        .order("conversations_count DESC")
        .limit(limit)
    end
    
    def expired_broadcasts
      Broadcast.where(status: :active)
               .where("expires_at < ?", Time.current)
    end
    
    def broadcasts_for_recipient(user)
      Broadcast.joins(:broadcast_recipients)
               .where(broadcast_recipients: { user_id: user.id })
               .order(created_at: :desc)
    end
    
    def unheard_broadcasts_for(user)
      broadcasts_for_recipient(user)
        .where(broadcast_recipients: { heard_at: nil })
    end
    
    def heard_broadcasts_for(user)
      broadcasts_for_recipient(user)
        .where.not(broadcast_recipients: { heard_at: nil })
    end
    
    def create_with_recipients(broadcast_params, recipient_ids)
      ActiveRecord::Base.transaction do
        broadcast = Broadcast.create!(broadcast_params)
        
        # 수신자 레코드 생성
        recipient_records = recipient_ids.map do |user_id|
          {
            broadcast_id: broadcast.id,
            user_id: user_id,
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        
        BroadcastRecipient.insert_all(recipient_records) if recipient_records.any?
        
        broadcast
      end
    end
    
    def mark_as_heard(broadcast, user)
      recipient = BroadcastRecipient.find_by(
        broadcast: broadcast,
        user: user
      )
      
      recipient&.update(heard_at: Time.current)
    end
    
    def statistics_for_user(user)
      broadcasts = by_user(user.id)
      
      {
        total_count: broadcasts.count,
        active_count: broadcasts.active.count,
        total_recipients: BroadcastRecipient.where(broadcast: broadcasts).count,
        total_conversations: Conversation.where(broadcast: broadcasts).count,
        average_recipients: broadcasts.joins(:broadcast_recipients)
                                     .group("broadcasts.id")
                                     .average("COUNT(broadcast_recipients.id)")
      }
    end
    
    # 성능 최적화를 위한 메서드
    def preload_associations(broadcasts, *associations)
      ActiveRecord::Associations::Preloader.new.preload(broadcasts, associations)
      broadcasts
    end
    
    def in_batches(batch_size: 1000, &block)
      Broadcast.in_batches(of: batch_size, &block)
    end
  end
  
  # 인스턴스 메서드 버전
  def initialize
    # 의존성 주입을 위한 초기화
  end
  
  def find_with_details(id)
    self.class.find_with_details(id)
  end
  
  def active_broadcasts
    self.class.active_broadcasts
  end
  
  def recent_broadcasts(limit: 20, since: nil)
    self.class.recent_broadcasts(limit: limit, since: since)
  end
  
  def by_user(user_id)
    self.class.by_user(user_id)
  end
  
  def search(conditions = {})
    self.class.search(conditions)
  end
  
  def create_with_recipients(broadcast_params, recipient_ids)
    self.class.create_with_recipients(broadcast_params, recipient_ids)
  end
  
  def mark_as_heard(broadcast, user)
    self.class.mark_as_heard(broadcast, user)
  end
end 