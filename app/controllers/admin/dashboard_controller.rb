# app/controllers/admin/dashboard_controller.rb
module Admin
  class DashboardController < Admin::BaseController
    # 대시보드 메인 페이지
    def index
      stats = {
        pending_reports_count: Report.where(status: :pending).count,
        reports_today_count: Report.where("created_at >= ?", Time.current.beginning_of_day).count,
        active_suspensions_count: UserSuspension.currently_active.count,
        users_count: User.count,
        users_today_count: User.where("created_at >= ?", Time.current.beginning_of_day).count,
        broadcasts_count: Broadcast.count,
        broadcasts_today_count: Broadcast.where("created_at >= ?", Time.current.beginning_of_day).count,
      }

      recent_reports = Report.order(created_at: :desc).limit(10).map { |r|
        {
          id: r.id,
          reason: r.reason,
          status: r.status,
          created_at: r.created_at.iso8601,
          reporter_id: r.reporter_id,
          reported_id: r.reported_id,
        }
      }

      render inertia: "Admin/Dashboard", props: {
        stats: stats,
        recent_reports: recent_reports,
      }
    end

    # 신고 관리 페이지
    def reports
      reports = Report.order(created_at: :desc).page(params[:page]).per(20)
      reports = reports.where(status: params[:status]) if params[:status].present?

      render inertia: "Admin/Reports", props: {
        reports: reports.map { |r| serialize_report(r) },
        pagination: pagination_meta(reports),
        filter: params[:status],
      }
    end

    # 신고 처리
    def process_report
      report = Report.find(params[:id])
      if ReportHandlerService.process_report(report)
        redirect_to admin_reports_path, notice: "신고가 성공적으로 처리되었습니다."
      else
        redirect_to admin_reports_path, alert: "신고 처리 중 오류가 발생했습니다."
      end
    end

    # 신고 거부
    def reject_report
      report = Report.find(params[:id])
      report.update(status: :rejected)
      redirect_to admin_reports_path, notice: "신고가 거부되었습니다."
    end

    # 사용자 관리 페이지
    def users
      users = User.order(created_at: :desc).page(params[:page]).per(20)
      users = users.where(blocked: true) if params[:status] == "blocked"

      render inertia: "Admin/Users", props: {
        users: users.map { |u| serialize_admin_user(u) },
        pagination: pagination_meta(users),
        filter: params[:status],
      }
    end

    # 사용자 정지
    def suspend_user
      user = User.find(params[:id])
      duration = params[:duration].to_i.days
      reason = params[:reason].presence || "관리자에 의한 정지"

      UserSuspension.create!(
        user: user,
        reason: reason,
        suspended_at: Time.current,
        suspended_until: Time.current + duration,
        suspended_by: current_admin.email,
        active: true
      )
      user.update(blocked: true)

      redirect_to admin_users_path, notice: "사용자가 #{duration / 1.day}일간 정지되었습니다."
    end

    # 사용자 정지 해제
    def unsuspend_user
      user = User.find(params[:id])
      user.user_suspensions.active.update_all(active: false)
      user.update(blocked: false)

      redirect_to admin_users_path, notice: "사용자의 정지가 해제되었습니다."
    end

    private

    def pagination_meta(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        per_page: collection.limit_value
      }
    end

    def serialize_report(report)
      {
        id: report.id,
        reason: report.reason,
        status: report.status,
        reporter_id: report.reporter_id,
        reported_id: report.reported_id,
        created_at: report.created_at.iso8601,
      }
    end

    def serialize_admin_user(user)
      {
        id: user.id,
        nickname: user.nickname,
        phone_number: user.phone_number,
        blocked: user.blocked,
        status: user.status,
        created_at: user.created_at.iso8601,
        broadcasts_count: user.broadcasts.count,
      }
    end
  end
end
