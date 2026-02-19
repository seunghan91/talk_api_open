class Api::V1::AnnouncementsController < Api::V1::BaseController
  before_action :require_admin, except: [ :index, :show ]
  before_action :set_announcement, only: [ :show, :update, :destroy ]

  def index
    announcements = Announcement.includes(:category).sorted

    # 관리자가 아닌 경우 공개된 공지사항만 표시
    unless current_user&.admin?
      announcements = announcements.published.visible
    end

    # 카테고리별 필터링
    if params[:category_id].present?
      announcements = announcements.where(category_id: params[:category_id])
    end

    render json: {
      announcements: announcements.map { |a| announcement_json(a) },
      pagination: {
        total: announcements.count,
        per_page: 10,
        current_page: (params[:page] || 1).to_i,
        last_page: (announcements.count / 10.0).ceil
      },
      success: true
    }
  end

  def show
    # 관리자가 아니고 숨겨진 공지사항인 경우 접근 불가
    if @announcement.is_hidden && !current_user&.admin?
      return render json: { success: false, error: "접근할 수 없는 공지사항입니다." }, status: :forbidden
    end

    # 관리자가 아니고 미게시 공지사항인 경우 접근 불가
    if !@announcement.is_published && !current_user&.admin?
      return render json: { success: false, error: "아직 게시되지 않은 공지사항입니다." }, status: :forbidden
    end

    render json: announcement_json(@announcement)
  end

  def create
    announcement = Announcement.new(announcement_params)

    # 게시일자 설정
    if announcement.is_published && announcement.published_at.nil?
      announcement.published_at = Time.current
    end

    if announcement.save
      render json: {
        announcement: announcement_json(announcement),
        success: true,
        message: "공지사항이 생성되었습니다."
      }, status: :created
    else
      render json: {
        errors: announcement.errors.full_messages,
        success: false
      }, status: :unprocessable_entity
    end
  end

  def update
    # 게시 상태가 변경된 경우 게시일자 업데이트
    if !@announcement.is_published && params[:announcement][:is_published] == true
      @announcement.published_at = Time.current
    end

    if @announcement.update(announcement_params)
      render json: {
        announcement: announcement_json(@announcement),
        success: true,
        message: "공지사항이 수정되었습니다."
      }
    else
      render json: {
        errors: @announcement.errors.full_messages,
        success: false
      }, status: :unprocessable_entity
    end
  end

  def destroy
    @announcement.destroy
    render json: { success: true, message: "공지사항이 삭제되었습니다." }
  end

  private

  def set_announcement
    @announcement = Announcement.includes(:category).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "공지사항을 찾을 수 없습니다." }, status: :not_found
  end

  def announcement_params
    params.require(:announcement).permit(
      :title,
      :content,
      :category_id,
      :is_important,
      :is_published,
      :is_hidden
    )
  end

  def announcement_json(announcement)
    {
      id: announcement.id,
      title: announcement.title,
      content: announcement.content,
      category_id: announcement.category_id,
      category: {
        id: announcement.category.id,
        name: announcement.category.name
      },
      is_important: announcement.is_important,
      is_published: announcement.is_published,
      is_hidden: announcement.is_hidden,
      created_at: announcement.created_at,
      updated_at: announcement.updated_at,
      published_at: announcement.published_at
    }
  end

  def require_admin
    unless current_user && current_user.admin?
      render json: { success: false, error: "관리자 권한이 필요합니다." }, status: :forbidden
    end
  end
end
