# app/services/report_handler_service.rb
# 신고 유형별 자동 처리 및 단계적 제재 관리를 위한 서비스 클래스
class ReportHandlerService
  # 성별 위장 신고의 제재 임계값 - 1회 발생 시 즉시 제재 (One-strike policy)
  GENDER_IMPERSONATION_THRESHOLD = 1

  # 불건전 콘텐츠 신고의 제재 임계값 - 3회 누적 시 제재
  INAPPROPRIATE_CONTENT_THRESHOLD = 3

  # 일반 신고의 제재 임계값 - 5회 누적 시 제재
  GENERAL_REPORT_THRESHOLD = 5

  def self.process_report(report)
    return false unless report.pending?

    # 처리 중 상태로 변경
    report.status_processing!

    # 신고 유형에 따른 처리
    case report.reason
    when "gender_impersonation"
      handle_gender_impersonation(report)
    when "inappropriate_content"
      handle_inappropriate_content(report)
    else
      handle_general_report(report)
    end

    # 처리 완료로 변경
    report.status_resolved!
    true
  rescue => e
    Rails.logger.error("신고 처리 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
    false
  end

  private

  # 성별 위장 신고 처리
  def self.handle_gender_impersonation(report)
    reported_user = report.reported
    count = Report.where(reported: reported_user, reason: "gender_impersonation", status: [ :resolved ]).count

    if count >= GENDER_IMPERSONATION_THRESHOLD
      # 1회 이상 누적 시 계정 정지
      suspend_user(reported_user, 1.day, "성별 위장 신고 #{count}회 누적")
      # 관리자에게 알림
      notify_admin(
        "성별 위장 신고로 사용자 정지",
        "사용자 ID: #{reported_user.id}, 닉네임: #{reported_user.nickname}, 신고 누적: #{count}회"
      )
    end
  end

  # 불건전 콘텐츠 신고 처리
  def self.handle_inappropriate_content(report)
    reported_user = report.reported
    count = Report.where(reported: reported_user, reason: "inappropriate_content", status: [ :resolved ]).count

    if count >= INAPPROPRIATE_CONTENT_THRESHOLD
      # 3회 이상 누적 시 계정 정지 (3일)
      suspend_user(reported_user, 3.days, "불건전 콘텐츠 신고 #{count}회 누적")
      # 관리자에게 알림
      notify_admin(
        "불건전 콘텐츠 신고로 사용자 정지",
        "사용자 ID: #{reported_user.id}, 닉네임: #{reported_user.nickname}, 신고 누적: #{count}회"
      )
    elsif count >= 1
      # 1회 누적 시 경고
      warn_user(reported_user, "불건전 콘텐츠 신고 #{count}회 누적")
    end
  end

  # 일반 신고 처리
  def self.handle_general_report(report)
    reported_user = report.reported
    count = Report.where(reported: reported_user, status: [ :resolved ]).count

    if count >= GENERAL_REPORT_THRESHOLD
      # 5회 이상 누적 시 계정 정지 (1일)
      suspend_user(reported_user, 1.day, "일반 신고 #{count}회 누적")
      # 관리자에게 알림
      notify_admin(
        "일반 신고 누적으로 사용자 정지",
        "사용자 ID: #{reported_user.id}, 닉네임: #{reported_user.nickname}, 신고 누적: #{count}회"
      )
    end
  end

  # 사용자 계정 정지 처리
  def self.suspend_user(user, duration, reason)
    return if user.blocked?

    # 계정 정지 처리
    user.update(blocked: true)

    # 정지 기록 생성 (사용자 정의 모델 필요)
    UserSuspension.create(
      user: user,
      reason: reason,
      suspended_at: Time.current,
      suspended_until: Time.current + duration,
      suspended_by: "system"
    ) if defined?(UserSuspension)

    # 사용자에게 정지 알림 발송
    send_suspension_notification(user, duration, reason)
  end

  # 사용자 경고 처리
  def self.warn_user(user, reason)
    # 사용자 경고 카운트 증가 (User 모델에 warning_count 필드 필요)
    user.increment!(:warning_count) if user.has_attribute?(:warning_count)

    # 사용자에게 경고 알림 발송
    send_warning_notification(user, reason)
  end

  # 사용자 정지 알림 발송
  def self.send_suspension_notification(user, duration, reason)
    # 실제 구현은 NotificationWorker를 사용하거나 직접 구현
    if defined?(NotificationWorker)
      NotificationWorker.perform_async(
        user.id,
        "account_suspension",
        "계정 정지 알림",
        "귀하의 계정이 #{reason}(으)로 #{ActionController::Base.helpers.distance_of_time_in_words(duration)}간 정지되었습니다.",
        { suspension_reason: reason, suspension_duration: duration.to_i }
      )
    end
  end

  # 사용자 경고 알림 발송
  def self.send_warning_notification(user, reason)
    # 실제 구현은 NotificationWorker를 사용하거나 직접 구현
    if defined?(NotificationWorker)
      NotificationWorker.perform_async(
        user.id,
        "account_warning",
        "계정 경고 알림",
        "귀하의 계정이 #{reason}(으)로 경고를 받았습니다. 추가 위반 시 계정이 정지될 수 있습니다.",
        { warning_reason: reason }
      )
    end
  end

  # 관리자 알림 발송
  def self.notify_admin(title, message)
    # 실제 구현은 AdminNotificationService 등을 사용
    Rails.logger.info("[관리자 알림] #{title}: #{message}")
    # AdminNotificationService.notify(title, message) if defined?(AdminNotificationService)
  end
end
