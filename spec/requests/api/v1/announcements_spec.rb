require 'rails_helper'

RSpec.describe "Api::V1::Announcements", type: :request do
  # Test data setup
  let!(:category) { create(:announcement_category, name: "General") }
  let!(:announcement) { create(:announcement, title: "Test Announcement", content: "Test Content", category: category, is_published: true) }

  # JSON response helper
  def json_response
    JSON.parse(response.body)
  end

  describe "GET /api/v1/announcements" do
    it "returns http success" do
      get "/api/v1/announcements"
      expect(response).to have_http_status(:success)
    end

    it "returns announcements list" do
      get "/api/v1/announcements"
      expect(json_response).to have_key('announcements')
      expect(json_response['success']).to eq(true)
    end

    it "filters by category_id" do
      get "/api/v1/announcements", params: { category_id: category.id }
      expect(response).to have_http_status(:success)
      expect(json_response['announcements'].length).to eq(1)
    end
  end

  describe "GET /api/v1/announcements/:id" do
    it "returns http success" do
      get "/api/v1/announcements/#{announcement.id}"
      expect(response).to have_http_status(:success)
    end

    it "returns the announcement details" do
      get "/api/v1/announcements/#{announcement.id}"
      expect(json_response['id']).to eq(announcement.id)
      expect(json_response['title']).to eq("Test Announcement")
    end

    it "returns not found for non-existent announcement" do
      get "/api/v1/announcements/99999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/announcements" do
    let(:valid_params) do
      {
        announcement: {
          title: "New Announcement",
          content: "New announcement content",
          category_id: category.id,
          is_important: true,
          is_published: true
        }
      }
    end

    let(:invalid_params) do
      {
        announcement: {
          title: "",
          content: ""
        }
      }
    end

    it "creates a new announcement with valid params" do
      expect {
        post "/api/v1/announcements", params: valid_params
      }.to change(Announcement, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['success']).to eq(true)
      expect(json_response['announcement']['title']).to eq("New Announcement")
    end

    it "returns error with invalid params" do
      post "/api/v1/announcements", params: invalid_params
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['success']).to eq(false)
      expect(json_response['errors']).to be_present
    end
  end

  describe "PATCH /api/v1/announcements/:id" do
    let(:update_params) do
      {
        announcement: {
          title: "Updated Title",
          content: "Updated content"
        }
      }
    end

    it "updates the announcement" do
      patch "/api/v1/announcements/#{announcement.id}", params: update_params
      expect(response).to have_http_status(:success)
      expect(json_response['success']).to eq(true)
      expect(json_response['announcement']['title']).to eq("Updated Title")
    end

    it "returns not found for non-existent announcement" do
      patch "/api/v1/announcements/99999", params: update_params
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/announcements/:id" do
    it "deletes the announcement" do
      expect {
        delete "/api/v1/announcements/#{announcement.id}"
      }.to change(Announcement, :count).by(-1)

      expect(response).to have_http_status(:success)
      expect(json_response['success']).to eq(true)
    end

    it "returns not found for non-existent announcement" do
      delete "/api/v1/announcements/99999"
      expect(response).to have_http_status(:not_found)
    end
  end
end
