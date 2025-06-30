# frozen_string_literal: true

class UserRepository
  class << self
    def find_by_phone_number(phone_number)
      User.find_by(phone_number: phone_number)
    end
    
    def active_users
      User.where(status: :active)
    end
    
    def find_with_profile(id)
      User.includes(:wallet, :user_suspensions).find(id)
    end
    
    def search(conditions = {})
      query = User.all
      
      # 닉네임 검색 (부분 일치)
      if conditions[:nickname].present?
        query = query.where("nickname LIKE ?", "%#{conditions[:nickname]}%")
      end
      
      # 전화번호 검색 (부분 일치)
      if conditions[:phone_number].present?
        query = query.where("phone_number LIKE ?", "%#{conditions[:phone_number]}%")
      end
      
      # 성별 필터
      if conditions[:gender].present?
        query = query.where(gender: conditions[:gender])
      end
      
      # 연령대 필터
      if conditions[:age_group].present?
        query = query.where(age_group: conditions[:age_group])
      end
      
      # 지역 필터
      if conditions[:region].present?
        query = query.where(region: conditions[:region])
      end
      
      query
    end
    
    def recently_active(limit: 10, since: nil)
      query = User.where.not(last_active_at: nil)
      query = query.where("last_active_at > ?", since) if since
      query.order(last_active_at: :desc).limit(limit)
    end
    
    def with_broadcasts_count
      User.left_joins(:broadcasts)
          .group("users.id")
          .select("users.*, COUNT(broadcasts.id) as broadcasts_count")
    end
    
    def blocked_by(blocker)
      User.joins(:received_blocks)
          .where(blocks: { blocker_id: blocker.id })
    end
    
    def create_with_profile(params)
      ActiveRecord::Base.transaction do
        user = User.new(params.slice(:phone_number, :password))
        user.assign_attributes(params.slice(:nickname, :gender, :age_group, :region))
        
        # 프로필 완성 여부 체크
        profile_fields = [:nickname, :gender, :age_group, :region]
        user.profile_completed = profile_fields.all? { |field| params[field].present? }
        
        user.save!
        user
      end
    end
    
    def with_associations(*associations)
      User.includes(*associations)
    end
    
    # 추가 유용한 쿼리 메서드들
    
    def find_by_ids(ids)
      User.where(id: ids)
    end
    
    def suspended_users
      User.where(status: :suspended)
    end
    
    def with_completed_profiles
      User.where(profile_completed: true)
    end
    
    def by_region(region)
      User.where(region: region)
    end
    
    def by_age_group(age_group)
      User.where(age_group: age_group)
    end
    
    def by_gender(gender)
      User.where(gender: gender)
    end
    
    def online_users
      User.where("last_active_at > ?", 5.minutes.ago)
    end
    
    def top_broadcasters(limit: 10)
      with_broadcasts_count
        .having("COUNT(broadcasts.id) > 0")
        .order("broadcasts_count DESC")
        .limit(limit)
    end
    
    def new_users(since: 7.days.ago)
      User.where("created_at > ?", since)
    end
    
    def with_recent_broadcasts(since: 24.hours.ago)
      User.joins(:broadcasts)
          .where("broadcasts.created_at > ?", since)
          .distinct
    end
  end
  
  # 인스턴스 메서드 버전 (필요한 경우)
  def initialize
    # 필요한 경우 의존성 주입을 위한 초기화
  end
  
  def find_by_phone_number(phone_number)
    self.class.find_by_phone_number(phone_number)
  end
  
  def active_users
    self.class.active_users
  end
  
  def find_with_profile(id)
    self.class.find_with_profile(id)
  end
  
  def search(conditions = {})
    self.class.search(conditions)
  end
  
  def recently_active(limit: 10, since: nil)
    self.class.recently_active(limit: limit, since: since)
  end
  
  def with_broadcasts_count
    self.class.with_broadcasts_count
  end
  
  def blocked_by(blocker)
    self.class.blocked_by(blocker)
  end
  
  def create_with_profile(params)
    self.class.create_with_profile(params)
  end
  
  def with_associations(*associations)
    self.class.with_associations(*associations)
  end
end 