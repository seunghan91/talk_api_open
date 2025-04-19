# app/controllers/admin/dashboard_controller.rb
# 관리자 대시보드를 위한 컨트롤러
# 신고/차단 관리 및 사용자 관리 기능 제공
module Admin
  class DashboardController < Admin::BaseController
    
    # 대시보드 메인 페이지 - 전반적인 통계 정보 표시
    def index
      # 신고 관련 통계 정보 가져오기
      @pending_reports_count = Report.where(status: :pending).count
      @reports_today_count = Report.where('created_at >= ?', Time.current.beginning_of_day).count
      
      # 차단 관련 통계 정보 가져오기
      @active_suspensions_count = UserSuspension.currently_active.count
      @suspensions_today_count = UserSuspension.where('created_at >= ?', Time.current.beginning_of_day).count
      
      # 사용자 관련 통계 정보 가져오기
      @users_count = User.count
      @users_today_count = User.where('created_at >= ?', Time.current.beginning_of_day).count
      @blocked_users_count = User.where(blocked: true).count
      
      # 브로드캐스트 관련 통계 정보 가져오기
      @broadcasts_count = Broadcast.count
      @broadcasts_today_count = Broadcast.where('created_at >= ?', Time.current.beginning_of_day).count
      
      # 최근 10개의 신고 내역 가져오기
      @recent_reports = Report.order(created_at: :desc).limit(10)
      
      # 최근 10개의 정지된 계정 가져오기
      @recent_suspensions = UserSuspension.currently_active.order(created_at: :desc).limit(10)
    end
    
    # 신고 관리 페이지 - 신고 목록 및 처리 기능 제공
    def reports
      # 신고 목록 페이징 처리 (최신순 20개씩)
      @reports = Report.order(created_at: :desc).page(params[:page]).per(20)
      
      # 신고 상태 필터링 적용 (상태 파라미터가 있는 경우)
      @reports = @reports.where(status: params[:status]) if params[:status].present?
    end
    
    # 신고 처리 액션 - 신고를 처리하고 해당 사용자에게 적절한 제재 적용
    def process_report
      @report = Report.find(params[:id])
      
      # ReportHandlerService를 통한 신고 처리 자동화
      if ReportHandlerService.process_report(@report)
        flash[:success] = "신고가 성공적으로 처리되었습니다."
      else
        flash[:error] = "신고 처리 중 오류가 발생했습니다."
      end
      
      redirect_to admin_reports_path
    end
    
    # 신고 거부 액션 - 신고를 거부하여 추가 처리 없이 마감
    def reject_report
      @report = Report.find(params[:id])
      @report.update(status: :rejected)
      
      flash[:success] = "신고가 거부되었습니다."
      redirect_to admin_reports_path
    end
    
    # 사용자 관리 페이지 - 사용자 목록 및 계정 정지 기능 제공
    def users
      # 사용자 목록 페이징 처리 (최신순 20개씩)
      @users = User.order(created_at: :desc).page(params[:page]).per(20)
      
      # 차단된 사용자만 필터링 (status=blocked 파라미터가 있는 경우)
      @users = @users.where(blocked: true) if params[:status] == 'blocked'
    end
    
    # 사용자 정지 액션 - 사용자 계정 정지 처리
    def suspend_user
      @user = User.find(params[:id])
      duration = params[:duration].to_i.days
      reason = params[:reason].presence || '관리자에 의한 정지'
      
      # 사용자 정지 기록 생성
      UserSuspension.create!(
        user: @user,
        reason: reason,
        suspended_at: Time.current,
        suspended_until: Time.current + duration,
        suspended_by: current_admin.email,
        active: true
      )
      
      # 사용자의 blocked 상태를 true로 변경하여 로그인 및 앱 사용 차단
      @user.update(blocked: true)
      
      flash[:success] = "사용자가 #{duration / 1.day}일간 정지되었습니다."
      redirect_to admin_users_path
    end
    
    # 사용자 정지 해제 액션 - 사용자 계정 정지를 해제하고 정상 상태로 복원
    def unsuspend_user
      @user = User.find(params[:id])
      
      # 해당 사용자의 모든 활성 정지 기록을 비활성화
      @user.user_suspensions.active.update_all(active: false)
      
      # 사용자의 blocked 상태를 false로 변경하여 정상 사용 가능하도록 복원
      @user.update(blocked: false)
      
      flash[:success] = "사용자의 정지가 해제되었습니다."
      redirect_to admin_users_path
    end
    
    private
    
    # 관리자 인증 처리 - 요청한 사용자가 관리자 권한을 가졌는지 확인
    def authenticate_admin!
      # 실제 프로덕션 환경에서는 Devise 같은 인증 시스템 사용 예정
      # 개발 환경에서만 사용할 테스트용 코드
      if Rails.env.development? || Rails.env.test?
        # 테스트용 더미 관리자 객체 생성
        # 실제 배포 환경에서는 사용하지 않음 - 프로덕션 환경용 인증 필요
        admin = OpenStruct.new(email: 'admin@example.com', id: 1)
        define_singleton_method(:current_admin) { admin }
      else
        # 실제 프로덕션 환경에서는 적절한 관리자 인증 기능 구현 필요
        redirect_to root_path, alert: '권한이 없습니다.' unless current_user&.admin?
      end
    end
  end
end
