class Api::TestController < ApplicationController
  def index
    # 공지사항 카테고리 조회
    categories = AnnouncementCategory.all

    # 공지사항 조회 (is_hidden=false인 것만)
    announcements = Announcement.where(is_hidden: false).includes(:category)

    render json: {
      categories: categories,
      announcements: announcements.map { |a|
        {
          id: a.id,
          title: a.title,
          content: a.content,
          category: {
            id: a.category_id,
            name: a.category.name
          },
          is_important: a.is_important,
          is_published: a.is_published,
          created_at: a.created_at,
          published_at: a.published_at
        }
      },
      success: true
    }
  end
end
