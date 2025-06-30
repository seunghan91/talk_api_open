module Broadcasts
  class RecipientSelectionService
    attr_reader :sender, :strategy, :filters, :query_builder

    def initialize(sender, strategy: :random, query_builder: nil)
      @sender = sender
      @strategy = strategy
      @filters = {}
      @query_builder = query_builder || DefaultQueryBuilder.new(sender)
    end

    def with_filters(filters)
      @filters = filters
      self # 체이닝을 위해 self 반환
    end

    def select_recipients(count:)
      eligible_users = query_builder.eligible_recipients(filters)

      case strategy
      when :activity_based
        select_by_activity(eligible_users, count)
      when :relationship_based
        select_by_relationship(eligible_users, count)
      else
        select_random(eligible_users, count)
      end
    end

    private

    def select_random(users, count)
      users.order("RANDOM()").limit(count)
    end

    def select_by_activity(users, count)
      users
        .where.not(last_login_at: nil)
        .order(last_login_at: :desc)
        .limit(count)
    end

    def select_by_relationship(users, count)
      # 대화 이력이 있는 사용자 우선
      users_with_history = users
        .joins("LEFT JOIN conversations ON
               (conversations.user_a_id = users.id AND conversations.user_b_id = #{sender.id})
               OR (conversations.user_b_id = users.id AND conversations.user_a_id = #{sender.id})")
        .group("users.id")
        .order("COUNT(conversations.id) DESC")
        .limit(count)

      # 부족한 경우 랜덤으로 추가
      if users_with_history.count < count
        remaining_count = count - users_with_history.count
        additional_users = users
          .where.not(id: users_with_history.pluck(:id))
          .order("RANDOM()")
          .limit(remaining_count)

        users_with_history + additional_users
      else
        users_with_history
      end
    end

    # 기본 쿼리 빌더
    class DefaultQueryBuilder
      def initialize(sender)
        @sender = sender
      end

      def eligible_recipients(filters = {})
        scope = User
          .where(status: :active)
          .where(verified: true)
          .where.not(id: @sender.id)

        # 차단 관계 제외
        blocked_user_ids = Block
          .where(blocker: @sender)
          .or(Block.where(blocked: @sender))
          .pluck(:blocked_id, :blocker_id)
          .flatten
          .uniq

        scope = scope.where.not(id: blocked_user_ids)

        # 필터 적용
        filters.each do |key, value|
          scope = scope.where(key => value) if value.present?
        end

        scope
      end
    end
  end
end
