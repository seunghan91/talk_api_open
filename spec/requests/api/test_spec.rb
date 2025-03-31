require 'rails_helper'

RSpec.describe "Api::Tests", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/api/test/index"
      expect(response).to have_http_status(:success)
    end
  end

end
