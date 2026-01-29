# frozen_string_literal: true

require_relative "concerns/readable_user_repository"
require_relative "concerns/writable_user_repository"

class UserRepository
  include ReadableUserRepository
  include WritableUserRepository

  # 인스턴스 메서드들 (Command 패턴에서 사용)
  def find_by_phone(phone_number)
    User.find_by(phone_number: phone_number)
  end

  def exists_by_phone?(phone_number)
    User.exists?(phone_number: phone_number)
  end

  def create_with_wallet(attributes)
    ActiveRecord::Base.transaction do
      user = User.create!(attributes)
      # User 모델의 after_create callback이 wallet을 생성하지 않은 경우에만 생성
      Wallet.create!(user: user, balance: 0) unless user.wallet.present?
      user.reload
    end
  end

  # Repository 특화 메서드들 (ReadableUserRepository에 없는 것들만)
  class << self
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
      User.joins(:blocks_as_blocked)
          .where(blocks: { blocker_id: blocker.id })
    end

    def create_with_profile(params)
      ActiveRecord::Base.transaction do
        user = User.new(params.slice(:phone_number, :password))
        user.assign_attributes(params.slice(:nickname, :gender, :age_group, :region))

        # 프로필 완성 여부 체크
        profile_fields = [ :nickname, :gender, :age_group, :region ]
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
      User.where(blocked: true)
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
end
