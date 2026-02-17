# app/services/broadcasts/recipient_selector.rb
module Broadcasts
  class RecipientSelector
    def initialize(strategy: nil)
      @strategy = strategy || RandomSelectionStrategy.new
    end

    def select(sender:, count:, exclude_blocked: true, target_gender: nil)
      candidates = find_candidates(sender, exclude_blocked, target_gender)
      @strategy.select(candidates, count)
    end

    private

    def find_candidates(sender, exclude_blocked, target_gender)
      scope = User.active
                  .where.not(id: sender.id)
                  .joins(:wallet)
                  .where("wallets.balance > ?", 0)

      if exclude_blocked
        # 차단한 사용자와 차단당한 사용자 제외
        blocked_user_ids = Block.where(blocker_id: sender.id).pluck(:blocked_id)
        blocking_user_ids = Block.where(blocked_id: sender.id).pluck(:blocker_id)
        excluded_ids = (blocked_user_ids + blocking_user_ids).uniq

        scope = scope.where.not(id: excluded_ids) if excluded_ids.any?
      end

      normalized_gender = normalize_gender(target_gender)
      scope = scope.where(gender: normalized_gender) if normalized_gender.present?

      scope
    end

    def normalize_gender(target_gender)
      return nil if target_gender.blank? || target_gender == "all"

      value = target_gender.to_s
      return value if %w[male female other].include?(value)

      nil
    end
  end

  # Strategy Pattern 구현
  class SelectionStrategy
    def select(candidates, count)
      raise NotImplementedError
    end
  end

  # 랜덤 선택 전략 (기본)
  class RandomSelectionStrategy < SelectionStrategy
    def select(candidates, count)
      candidates.order("RANDOM()").limit(count)
    end
  end

  # 활동성 기반 선택 전략
  class ActivityBasedStrategy < SelectionStrategy
    def select(candidates, count)
      # 최근 활동이 많은 사용자 우선
      candidates.order(last_active_at: :desc)
                .limit(count * 2) # 여유분 확보
                .sample(count)
    end
  end

  # 지역 기반 선택 전략
  class LocationBasedStrategy < SelectionStrategy
    def initialize(sender_region)
      @sender_region = sender_region
    end

    def select(candidates, count)
      # 같은 지역 사용자 50% + 다른 지역 50%
      same_region_count = count / 2
      other_region_count = count - same_region_count

      same_region = candidates.where(region: @sender_region)
                              .order("RANDOM()")
                              .limit(same_region_count)
                              .to_a

      other_region = candidates.where.not(region: @sender_region)
                               .order("RANDOM()")
                               .limit(other_region_count)
                               .to_a

      same_region + other_region
    end
  end

  # 관심사 기반 선택 전략
  class InterestBasedStrategy < SelectionStrategy
    def initialize(sender_interests)
      @sender_interests = sender_interests
    end

    def select(candidates, count)
      # 관심사 매칭 점수 계산
      scored_candidates = candidates.map do |user|
        score = calculate_interest_score(user)
        { user: user, score: score }
      end

      # 점수 높은 순으로 정렬 후 상위 N명 선택
      scored_candidates.sort_by { |c| -c[:score] }
                       .first(count)
                       .map { |c| c[:user] }
    end

    private

    def calculate_interest_score(user)
      return 0 unless user.interests.any?
      
      # 공통 관심사 수 계산
      common_interests = user.interests & @sender_interests
      common_interests.count.to_f / @sender_interests.count
    end
  end

  # 혼합 전략 (여러 전략 조합)
  class MixedStrategy < SelectionStrategy
    def initialize(strategies_with_weights)
      @strategies_with_weights = strategies_with_weights
    end

    def select(candidates, count)
      results = []
      
      @strategies_with_weights.each do |strategy, weight|
        selection_count = (count * weight).round
        selected = strategy.select(candidates, selection_count)
        results.concat(selected.to_a)
      end

      # 중복 제거 후 필요한 수만큼 반환
      results.uniq.first(count)
    end
  end

  # 테스트용 전략
  class TestStrategy < SelectionStrategy
    def select(candidates, count)
      # 테스트 계정들만 선택
      test_phone_patterns = %w[01011111111 01022222222 01033333333 01044444444 01055555555]
      
      candidates.where(phone_number: test_phone_patterns)
                .limit(count)
    end
  end
end 
