module Admin
  class AnalyticsController < ActionController::Base
    layout 'rails_admin/application'
    before_action :authenticate_admin
    skip_forgery_protection
    
    def index
      @summary = AnalyticsService.dashboard_summary
      
      # 오늘 통계
      @today_stats = {
        dau: @summary[:today][:dau],
        new_users: @summary[:today][:new_users],
        broadcasts: @summary[:today][:broadcasts],
        messages: @summary[:today][:messages],
        reports: @summary[:today][:reports]
      }
      
      # 어제 통계
      @yesterday_stats = {
        dau: @summary[:yesterday][:dau],
        new_users: @summary[:yesterday][:new_users],
        broadcasts: @summary[:yesterday][:broadcasts],
        messages: @summary[:yesterday][:messages],
        reports: @summary[:yesterday][:reports]
      }
      
      # 주간 통계
      @week_stats = @summary[:week]
      
      # 월간 통계
      @month_stats = @summary[:month]
      
      # 브로드캐스트 응답률
      @broadcast_response_rate = AnalyticsService.broadcast_stats[:response_rate]
      
      # 대화 통계
      @conversation_stats = AnalyticsService.conversation_stats
      
      # 신고 통계
      @report_stats = AnalyticsService.report_stats
    end
    
    def daily
      @date = params[:date].present? ? Date.parse(params[:date]) : Date.today
      
      @dau = AnalyticsService.daily_active_users(@date)
      @new_users = AnalyticsService.new_users(@date)
      @broadcast_stats = AnalyticsService.broadcast_stats(@date)
      @conversation_stats = AnalyticsService.conversation_stats(@date)
      @report_stats = AnalyticsService.report_stats(@date)
    end
    
    def weekly
      @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today
      @start_date = @end_date - 6.days
      
      @stats = AnalyticsService.period_stats(@start_date, @end_date)
    end
    
    def monthly
      @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today
      @start_date = @end_date - 29.days
      
      @stats = AnalyticsService.period_stats(@start_date, @end_date)
    end

    private

    def authenticate_admin
      # 필요한 경우 여기에 관리자 인증 로직을 구현
      # 예: RailsAdmin의 인증 방식과 동일하게 처리
      # 일단 모든 요청을 통과시키도록 설정
    end
  end
end 