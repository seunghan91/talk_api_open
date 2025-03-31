require 'rails_helper'

RSpec.describe "Api::V1::AnnouncementCategories", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/api/v1/announcement_categories/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/api/v1/announcement_categories/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/api/v1/announcement_categories/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/api/v1/announcement_categories/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
