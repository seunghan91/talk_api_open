# frozen_string_literal: true

class UserService
  FORBIDDEN_NICKNAMES = %w[관리자 운영자 admin administrator system].freeze
  AUTO_SUSPEND_REPORT_COUNT = 3
  DEFAULT_SUSPENSION_DAYS = 7

  Result = Struct.new(:success, :user, :report, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(notification_service: nil, wallet_service: nil)
    @notification_service = notification_service || NotificationService.new
    @wallet_service = wallet_service || WalletService.new
  end

  def create_user(params)
    ActiveRecord::Base.transaction do
      user = User.new(params)

      # 전화번호 유효성 검증
      unless valid_phone_number?(params[:phone_number])
        return Result.new(success: false, error: "유효하지 않은 전화번호 형식입니다")
      end

      # 중복 체크
      if User.exists?(phone_number: params[:phone_number])
        return Result.new(success: false, error: "이미 사용 중인 전화번호입니다")
      end

      # 사용자 생성
      if user.save
        # 지갑 생성
        @wallet_service.create_wallet_for_user(user)

        # 환영 알림 발송
        send_welcome_notification(user)

        Result.new(success: true, user: user)
      else
        Result.new(success: false, error: user.errors.full_messages.join(", "))
      end
    end
  rescue => e
    Rails.logger.error "UserService#create_user failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    Result.new(success: false, error: "사용자 생성 중 오류가 발생했습니다")
  end

  def suspend_user(user, reason:, duration_days: DEFAULT_SUSPENSION_DAYS, admin: nil)
    ActiveRecord::Base.transaction do
      # 정지 기록 생성
      suspension = user.user_suspensions.create!(
        reason: reason,
        suspended_at: Time.current,
        suspended_until: duration_days.days.from_now,
        active: true
      )

      # 사용자 상태 업데이트
      user.status = :suspended
      user.save!

      # 정지 알림 발송
      @notification_service.send_notification(
        user: user,
        type: :suspension_notice,
        title: "계정 정지 안내",
        body: "귀하의 계정이 #{duration_days}일 동안 정지되었습니다. 사유: #{reason}",
        data: {
          reason: reason,
          until: suspension.suspended_until,
          duration_days: duration_days
        }
      )

      # 정지 해제 작업 스케줄링
      ExpiredSuspensionWorker.perform_at(suspension.suspended_until, user.id)

      Result.new(success: true, user: user)
    end
  rescue => e
    Rails.logger.error "UserService#suspend_user failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    Result.new(success: false, error: "사용자 정지 처리 중 오류가 발생했습니다: #{e.message}")
  end

  def block_user(blocker:, blocked:)
    # 자기 자신 차단 방지
    if blocker.id == blocked.id
      return Result.new(success: false, error: "자기 자신을 차단할 수 없습니다")
    end

    # 중복 차단 방지
    if Block.exists?(blocker: blocker, blocked: blocked)
      return Result.new(success: false, error: "이미 차단된 사용자입니다")
    end

    Block.create!(blocker: blocker, blocked: blocked)
    Result.new(success: true)
  rescue => e
    Rails.logger.error "UserService#block_user failed: #{e.message}"
    Result.new(success: false, error: "차단 처리 중 오류가 발생했습니다")
  end

  def report_user(reporter:, reported:, reason:)
    ActiveRecord::Base.transaction do
      # 신고 생성
      report = Report.create!(
        reporter: reporter,
        reported: reported,
        reason: reason,
        status: :pending,
        report_type: :user
      )

      # 신고 횟수 확인 및 자동 정지 처리
      confirmed_reports_count = Report.where(
        reported: reported,
        status: :resolved
      ).count

      if confirmed_reports_count >= AUTO_SUSPEND_REPORT_COUNT - 1
        suspend_result = suspend_user(
          reported,
          reason: "반복된 신고로 인한 자동 정지 (#{reason})",
          duration_days: DEFAULT_SUSPENSION_DAYS
        )
        Result.new(success: true, report: report, user: suspend_result.user)
      else
        Result.new(success: true, report: report, user: reported)
      end
    end
  rescue => e
    Rails.logger.error "UserService#report_user failed: #{e.message}"
    Result.new(success: false, error: "신고 처리 중 오류가 발생했습니다")
  end

  def update_profile(user, params)
    # 금지된 닉네임 체크
    if params[:nickname] && forbidden_nickname?(params[:nickname])
      return Result.new(success: false, error: "사용할 수 없는 닉네임입니다")
    end

    # 프로필 업데이트
    if user.update(params)
      # 프로필 완성 여부 체크
      check_profile_completion(user)

      Result.new(success: true, user: user)
    else
      Result.new(success: false, error: user.errors.full_messages.join(", "))
    end
  rescue => e
    Rails.logger.error "UserService#update_profile failed: #{e.message}"
    Result.new(success: false, error: "프로필 업데이트 중 오류가 발생했습니다")
  end

  def check_suspension_expiry(user)
    return Result.new(success: true) unless user.status_suspended?

    active_suspension = user.user_suspensions.active.first
    return Result.new(success: true) unless active_suspension

    if active_suspension.suspended_until < Time.current
      ActiveRecord::Base.transaction do
        # 정지 해제
        active_suspension.update!(active: false)
        user.status = :active
        user.save!

        # 정지 해제 알림
        @notification_service.send_notification(
          user: user,
          type: :suspension_lifted,
          title: "계정 정지 해제",
          body: "귀하의 계정 정지가 해제되었습니다. 다시 서비스를 이용하실 수 있습니다.",
          data: { lifted_at: Time.current }
        )
      end

      Result.new(success: true, user: user)
    else
      Result.new(success: true, user: user)
    end
  rescue => e
    Rails.logger.error "UserService#check_suspension_expiry failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    Result.new(success: false, error: "정지 만료 확인 중 오류가 발생했습니다: #{e.message}")
  end

  private

  def valid_phone_number?(phone_number)
    return false unless phone_number.present?
    # 한국 전화번호 형식 검증 (01X-XXXX-XXXX)
    phone_number.gsub(/\D/, "").match?(/^01\d{8,9}$/)
  end

  def forbidden_nickname?(nickname)
    return false unless nickname.present?
    FORBIDDEN_NICKNAMES.any? { |forbidden| nickname.downcase.include?(forbidden) }
  end

  def check_profile_completion(user)
    required_fields = %i[nickname gender age_group region]
    completed = required_fields.all? { |field| user.send(field).present? }

    if completed && !user.profile_completed
      user.update_column(:profile_completed, true)

      # 프로필 완성 보상
      @wallet_service.add_points(user.wallet, 100, reason: "프로필 완성 보상")
    end
  end

  def send_welcome_notification(user)
    @notification_service.send_notification(
      user: user,
      type: :welcome,
      title: "Talkk에 오신 것을 환영합니다!",
      body: "프로필을 완성하고 100포인트를 받으세요!"
    )
  end
end
