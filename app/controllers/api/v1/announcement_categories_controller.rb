class Api::V1::AnnouncementCategoriesController < Api::V1::BaseController
  # 개발 환경에서는 인증 건너뜁니다 (테스트 용도)
  before_action :authenticate_user!, unless: -> { Rails.env.development? || Rails.env.test? }
  before_action :require_admin, except: [:index], unless: -> { Rails.env.development? || Rails.env.test? }
  before_action :set_category, only: [:update, :destroy]

  def index
    categories = AnnouncementCategory.sorted

    render json: {
      categories: categories,
      success: true
    }
  end

  def create
    category = AnnouncementCategory.new(category_params)

    if category.save
      render json: {
        category: category,
        success: true
      }, status: :created
    else
      render json: {
        errors: category.errors.full_messages,
        success: false
      }, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
      render json: {
        category: @category,
        success: true
      }
    else
      render json: {
        errors: @category.errors.full_messages,
        success: false
      }, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    render json: { success: true, message: "카테고리가 삭제되었습니다." }
  end

  private

  def set_category
    @category = AnnouncementCategory.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "카테고리를 찾을 수 없습니다." }, status: :not_found
  end

  def category_params
    params.require(:category).permit(:name, :description)
  end

  def require_admin
    unless current_user && current_user.admin?
      render json: { success: false, error: "관리자 권한이 필요합니다." }, status: :forbidden
    end
  end
end
