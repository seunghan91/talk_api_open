# frozen_string_literal: true

module Broadcasts
  class LimitService
    LimitCheckResult = Struct.new(:can_broadcast, :reason, :limit_info, keyword_init: true) do
      def can_broadcast?
        can_broadcast
      end
    end

    def initialize(broadcast_repository: nil)
      @broadcast_repository = broadcast_repository || BroadcastRepository.new
    end

    # ─── 제한 체크 (핵심 메서드) ───

    def check_limit(user)
      settings = SystemSetting.broadcast_limits

      # 1. 역할 기반 우회 체크
      if bypass_user?(user, settings)
        return LimitCheckResult.new(
          can_broadcast: true,
          reason: nil,
          limit_info: bypass_limit_info(settings)
        )
      end

      # 2. 일일 제한 체크
      daily_count = @broadcast_repository.count_today_by_user(user)
      daily_limit = settings["daily_limit"]

      if daily_count >= daily_limit
        BroadcastUsageLog.record_limit_exceeded!(user)
        return LimitCheckResult.new(
          can_broadcast: false,
          reason: "DAILY_LIMIT_EXCEEDED",
          limit_info: {
            daily_limit: daily_limit,
            daily_used: daily_count,
            daily_remaining: 0,
            next_reset_at: next_midnight.iso8601
          }
        )
      end

      # 3. 시간당 제한 체크
      hourly_limit = settings["hourly_limit"]
      if hourly_limit && hourly_limit > 0
        hourly_count = @broadcast_repository.count_hourly_by_user(user)

        if hourly_count >= hourly_limit
          BroadcastUsageLog.record_limit_exceeded!(user)
          return LimitCheckResult.new(
            can_broadcast: false,
            reason: "HOURLY_LIMIT_EXCEEDED",
            limit_info: {
              daily_limit: daily_limit,
              daily_used: daily_count,
              daily_remaining: daily_limit - daily_count,
              hourly_limit: hourly_limit,
              hourly_used: hourly_count,
              next_reset_at: next_midnight.iso8601
            }
          )
        end
      end

      # 4. 쿨다운 체크
      cooldown_minutes = settings["cooldown_minutes"]
      if cooldown_minutes && cooldown_minutes > 0
        last_time = @broadcast_repository.last_broadcast_time(user)

        if last_time
          cooldown_ends = last_time + cooldown_minutes.minutes

          if cooldown_ends > Time.current
            BroadcastUsageLog.record_limit_exceeded!(user)
            return LimitCheckResult.new(
              can_broadcast: false,
              reason: "COOLDOWN_ACTIVE",
              limit_info: {
                daily_limit: daily_limit,
                daily_used: daily_count,
                daily_remaining: daily_limit - daily_count,
                cooldown_ends_at: cooldown_ends.iso8601
              }
            )
          end
        end
      end

      # 모든 체크 통과
      LimitCheckResult.new(
        can_broadcast: true,
        reason: nil,
        limit_info: {
          daily_limit: daily_limit,
          daily_used: daily_count,
          daily_remaining: daily_limit - daily_count,
          next_reset_at: next_midnight.iso8601
        }
      )
    end

    # ─── 브로드캐스트 전송 후 사용량 기록 ───

    def record_broadcast(user)
      BroadcastUsageLog.record_broadcast!(user)
    end

    # ─── 제한 상태 조회 (API 응답용) ───

    def get_limit_status(user)
      settings = SystemSetting.broadcast_limits

      if bypass_user?(user, settings)
        return {
          daily_limit: settings["daily_limit"],
          daily_used: 0,
          daily_remaining: settings["daily_limit"],
          hourly_limit: settings["hourly_limit"],
          hourly_used: 0,
          next_reset_at: next_midnight.iso8601,
          can_broadcast: true,
          is_bypass: true
        }
      end

      daily_count = @broadcast_repository.count_today_by_user(user)
      daily_limit = settings["daily_limit"]
      hourly_limit = settings["hourly_limit"]
      hourly_count = hourly_limit ? @broadcast_repository.count_hourly_by_user(user) : 0
      cooldown_minutes = settings["cooldown_minutes"]

      can_broadcast = daily_count < daily_limit
      cooldown_ends_at = nil

      # 시간당 제한 체크
      if can_broadcast && hourly_limit && hourly_limit > 0
        can_broadcast = hourly_count < hourly_limit
      end

      # 쿨다운 체크
      if can_broadcast && cooldown_minutes && cooldown_minutes > 0
        last_time = @broadcast_repository.last_broadcast_time(user)
        if last_time
          cooldown_ends = last_time + cooldown_minutes.minutes
          if cooldown_ends > Time.current
            can_broadcast = false
            cooldown_ends_at = cooldown_ends.iso8601
          end
        end
      end

      result = {
        daily_limit: daily_limit,
        daily_used: daily_count,
        daily_remaining: [daily_limit - daily_count, 0].max,
        hourly_limit: hourly_limit || 0,
        hourly_used: hourly_count,
        next_reset_at: next_midnight.iso8601,
        can_broadcast: can_broadcast
      }

      result[:cooldown_ends_at] = cooldown_ends_at if cooldown_ends_at
      result
    end

    private

    def bypass_user?(user, settings)
      bypass_roles = settings["bypass_roles"] || []
      return true if user.admin? && bypass_roles.include?("admin")

      false
    end

    def bypass_limit_info(settings)
      {
        daily_limit: settings["daily_limit"],
        daily_used: 0,
        daily_remaining: settings["daily_limit"],
        is_bypass: true
      }
    end

    def next_midnight
      Time.current.tomorrow.beginning_of_day
    end
  end
end
