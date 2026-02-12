module Api
  module V1
    class ReportsController < Api::V1::BaseController
      before_action :authorize_request

      # POST /api/v1/reports
      def create
        attrs = report_params
        report_type = attrs[:report_type].to_s
        reported_id = attrs[:reported_id]

        if report_type == "feedback"
          # 피드백은 대상 사용자 없이 작성하므로 자기 자신을 내부 대상자로 사용
          reported_id ||= current_user.id
        end

        report = Report.new(
          reporter_id: current_user.id,
          reported_id: reported_id,
          report_type: report_type,
          reason: attrs[:reason],
          related_id: attrs[:related_id]
        )

        if report.reported_id == current_user.id && report.report_type != "feedback"
          return render json: { error: "자기 자신은 신고할 수 없습니다." }, status: :unprocessable_entity
        end

        if report.save
          render json: {
            message: "신고가 접수되었습니다.",
            report: serialize_report(report)
          }, status: :created
        else
          render json: { error: report.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error("신고 생성 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "신고를 처리하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end

      # GET /api/v1/reports/my_reports
      def my_reports
        reports = Report.where(reporter_id: current_user.id)
          .order(created_at: :desc)
          .page(params[:page])
          .per((params[:per_page] || 20).to_i)

        render json: {
          reports: reports.map { |report| serialize_report(report) },
          pagination: {
            current_page: reports.current_page,
            total_pages: reports.total_pages,
            total_count: reports.total_count
          }
        }, status: :ok
      rescue => e
        Rails.logger.error("내 신고 목록 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "내 신고 목록을 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
      end

      private

      def report_params
        source = params[:report].presence || params
        if source.respond_to?(:permit)
          source.permit(:reported_id, :report_type, :reason, :related_id)
        else
          ActionController::Parameters.new(source).permit(:reported_id, :report_type, :reason, :related_id)
        end
      end

      def serialize_report(report)
        {
          id: report.id,
          reporter_id: report.reporter_id,
          reported_id: report.reported_id,
          report_type: report.report_type,
          reason: report.reason,
          related_id: report.related_id,
          status: report.status,
          created_at: report.created_at,
          updated_at: report.updated_at
        }
      end
    end
  end
end
