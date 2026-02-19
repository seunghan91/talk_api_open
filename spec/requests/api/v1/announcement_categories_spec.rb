require 'rails_helper'

RSpec.describe "Api::V1::AnnouncementCategories", type: :request do
  let!(:user) { create(:user) }
  let!(:admin) { create(:user, is_admin: true) }

  describe "GET /api/v1/announcement_categories" do
    it "returns http success" do
      get "/api/v1/announcement_categories", headers: auth_headers_for(user)
      expect(response).to have_http_status(:success)
    end

    it "returns categories list" do
      create(:announcement_category, name: "General")
      get "/api/v1/announcement_categories", headers: auth_headers_for(user)

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["categories"]).to be_an(Array)
    end
  end

  describe "POST /api/v1/announcement_categories" do
    let(:valid_params) { { category: { name: "News", description: "News announcements" } } }
    let(:invalid_params) { { category: { name: "", description: "" } } }

    it "creates a category with valid params" do
      post "/api/v1/announcement_categories", params: valid_params, headers: auth_headers_for(admin)
      expect(response).to have_http_status(:created)

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["category"]["name"]).to eq("News")
    end

    it "returns unprocessable_entity with invalid params" do
      post "/api/v1/announcement_categories", params: invalid_params, headers: auth_headers_for(admin)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/announcement_categories/:id" do
    let!(:category) { create(:announcement_category, name: "Old Name") }
    let(:update_params) { { category: { name: "New Name" } } }

    it "updates the category" do
      patch "/api/v1/announcement_categories/#{category.id}", params: update_params, headers: auth_headers_for(admin)
      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["category"]["name"]).to eq("New Name")
    end

    it "returns not_found for non-existent category" do
      patch "/api/v1/announcement_categories/999999", params: update_params, headers: auth_headers_for(admin)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/announcement_categories/:id" do
    let!(:category) { create(:announcement_category) }

    it "deletes the category" do
      expect {
        delete "/api/v1/announcement_categories/#{category.id}", headers: auth_headers_for(admin)
      }.to change(AnnouncementCategory, :count).by(-1)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end

    it "returns not_found for non-existent category" do
      delete "/api/v1/announcement_categories/999999", headers: auth_headers_for(admin)
      expect(response).to have_http_status(:not_found)
    end
  end
end
