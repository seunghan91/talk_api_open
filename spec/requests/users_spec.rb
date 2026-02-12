require 'rails_helper'

RSpec.describe "Api::V1::Users", type: :request do
  # Test user and authentication headers
  let!(:user) { create(:user, phone_number: "01012345678", nickname: "테스트유저") }
  let(:auth_headers) { auth_headers_for(user) }

  # JSON response helper
  def json_response
    JSON.parse(response.body)
  end

  # ===================================================================
  #   GET /api/v1/users/profile - Get user profile
  # ===================================================================
  describe "GET /api/v1/users/profile" do
    context "with valid authentication" do
      it "returns the user profile successfully" do
        get "/api/v1/users/profile", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to include(
          'id' => user.id,
          'nickname' => user.nickname
        )
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        get "/api/v1/users/profile"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   GET /api/v1/users/me - Get current user information
  # ===================================================================
  describe "GET /api/v1/users/me" do
    context "with valid authentication" do
      it "returns current user information successfully" do
        get "/api/v1/users/me", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key('user')
        expect(json_response['user']).to include(
          'id' => user.id,
          'nickname' => user.nickname
        )
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        get "/api/v1/users/me"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   POST /api/v1/users/change_password - Change user password
  # ===================================================================
  describe "POST /api/v1/users/change_password" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          current_password: 'test1234',
          new_password: 'newpassword123',
          new_password_confirmation: 'newpassword123'
        }
      end

      it "changes the password successfully" do
        post "/api/v1/users/change_password", params: valid_params, headers: auth_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context "with mismatched password confirmation" do
      let(:invalid_params) do
        {
          current_password: 'test1234',
          new_password: 'newpassword123',
          new_password_confirmation: 'different'
        }
      end

      it "returns an error" do
        post "/api/v1/users/change_password", params: invalid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        post "/api/v1/users/change_password", params: { current_password: 'test' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   GET /api/v1/users/notification_settings - Get notification settings
  # ===================================================================
  describe "GET /api/v1/users/notification_settings" do
    context "with valid authentication" do
      it "returns notification settings successfully" do
        get "/api/v1/users/notification_settings", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to include(
          'push_enabled',
          'broadcast_push_enabled',
          'message_push_enabled'
        )
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        get "/api/v1/users/notification_settings"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   PUT /api/v1/users/notification_settings - Update notification settings
  # ===================================================================
  describe "PUT /api/v1/users/notification_settings" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          push_enabled: true,
          broadcast_push_enabled: false,
          message_push_enabled: true
        }
      end

      it "updates notification settings successfully" do
        put "/api/v1/users/notification_settings", params: valid_params, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to include('message')
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        put "/api/v1/users/notification_settings", params: { push_enabled: true }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   POST /api/v1/users/change_nickname - Change user nickname
  # ===================================================================
  describe "POST /api/v1/users/change_nickname" do
    context "with valid nickname" do
      let(:valid_params) { { nickname: '새닉네임123' } }

      it "changes the nickname successfully" do
        post "/api/v1/users/change_nickname", params: valid_params, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to include('message')
      end
    end

    context "with empty nickname" do
      let(:invalid_params) { { nickname: '' } }

      it "returns an error" do
        post "/api/v1/users/change_nickname", params: invalid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response).to have_key('error')
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        post "/api/v1/users/change_nickname", params: { nickname: 'test' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   GET /api/v1/users/random_nickname - Generate a random nickname
  # ===================================================================
  describe "GET /api/v1/users/random_nickname" do
    context "with valid authentication" do
      it "generates a random nickname successfully" do
        get "/api/v1/users/random_nickname", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key('nickname')
        expect(json_response['nickname']).to be_present
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        get "/api/v1/users/random_nickname"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   POST /api/v1/users/update_profile - Update user profile
  # ===================================================================
  describe "POST /api/v1/users/update_profile" do
    context "with valid parameters" do
      let(:valid_params) { { nickname: '새프로필', gender: 'male' } }

      it "updates the profile successfully" do
        post "/api/v1/users/update_profile", params: valid_params, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to include('message')
        expect(json_response).to have_key('user')
      end
    end

    context "with invalid nickname (too short)" do
      let(:invalid_params) { { nickname: 'a' } }

      it "returns an error" do
        post "/api/v1/users/update_profile", params: invalid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response).to have_key('error')
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        post "/api/v1/users/update_profile", params: { nickname: 'test' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
