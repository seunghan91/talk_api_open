# app/controllers/api/pages_controller.rb
module Api
  class PagesController < ActionController::Base
    # 여기선 인증 필요 없음 → skip or no filter
    # OR we can do nothing special, because we don't want to use authorize_request at all.

    def home
      # 암묵적으로 app/views/pages/home.html.erb 렌더
      # or render template: "pages/home"
    end
  end
end
