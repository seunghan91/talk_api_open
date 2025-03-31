require 'rails_helper'

RSpec.describe "Api::V1::Announcements", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/api/v1/announcements/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/api/v1/announcements/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/api/v1/announcements/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/api/v1/announcements/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/api/v1/announcements/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
