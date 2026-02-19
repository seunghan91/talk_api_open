# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ApiAuthentication concern", type: :request do
  # All tests exercise the concern through GET /api/v1/users/me,
  # which requires authorize_request via Api::V1::UsersController.

  let(:user) { create(:user) }

  # ---------------------------------------------------------------------------
  # Helper: build an Authorization header from a raw token string
  # ---------------------------------------------------------------------------
  def bearer_header(token)
    { "Authorization" => "Bearer #{token}" }
  end

  # ---------------------------------------------------------------------------
  # 1. Valid token -> 200, current_user set correctly
  # ---------------------------------------------------------------------------
  describe "valid token" do
    it "returns 200 and the authenticated user data" do
      session = create(:session, user: user)

      get "/api/v1/users/me", headers: bearer_header(session.token)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig("user", "id")).to eq(user.id)
      expect(body.dig("user", "nickname")).to eq(user.nickname)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Missing Authorization header -> 401
  # ---------------------------------------------------------------------------
  describe "missing Authorization header" do
    it "returns 401" do
      get "/api/v1/users/me"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Empty Bearer token ("Bearer ") -> 401
  # ---------------------------------------------------------------------------
  describe "empty Bearer token" do
    it "returns 401 when the token portion is blank" do
      get "/api/v1/users/me", headers: { "Authorization" => "Bearer " }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Invalid / non-existent token -> 401
  # ---------------------------------------------------------------------------
  describe "invalid token" do
    it "returns 401 for a completely fabricated token" do
      get "/api/v1/users/me", headers: bearer_header("nonexistent_token_abc123")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Expired session (last_active_at > 30 days ago) -> 401
  # ---------------------------------------------------------------------------
  describe "expired session" do
    it "returns 401 when the session has been inactive for more than 30 days" do
      session = create(:session, :expired, user: user)

      get "/api/v1/users/me", headers: bearer_header(session.token)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Session touch: valid request updates last_active_at
  # ---------------------------------------------------------------------------
  describe "session activity tracking" do
    it "updates last_active_at on each authenticated request" do
      session = create(:session, user: user, last_active_at: 5.days.ago)
      original_active_at = session.last_active_at

      freeze_time do
        get "/api/v1/users/me", headers: bearer_header(session.token)

        expect(response).to have_http_status(:ok)
        session.reload
        expect(session.last_active_at).to be_within(1.second).of(Time.current)
        expect(session.last_active_at).not_to eq(original_active_at)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Malformed headers -> 401
  # ---------------------------------------------------------------------------
  describe "malformed Authorization header" do
    it "returns 401 for Basic scheme" do
      get "/api/v1/users/me", headers: { "Authorization" => "Basic dXNlcjpwYXNz" }

      expect(response).to have_http_status(:unauthorized)
    end

    # NOTE: extract_token_from_header uses `split(" ").last` which does NOT
    # validate the scheme prefix. "Token xyz" and "Bearer xyz" both yield "xyz".
    # The following tests document the ACTUAL behavior of the concern.

    it "authenticates with Token scheme because the concern does not validate the scheme prefix" do
      session = create(:session, user: user)
      get "/api/v1/users/me", headers: { "Authorization" => "Token #{session.token}" }

      # This succeeds because split(" ").last extracts the valid token
      expect(response).to have_http_status(:ok)
    end

    it "authenticates with a bare token string because split.last returns it unchanged" do
      session = create(:session, user: user)
      get "/api/v1/users/me", headers: { "Authorization" => session.token }

      # "some_token".split(" ").last => "some_token" -- still a valid lookup
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Terminated session: after logout, token is invalid
  # ---------------------------------------------------------------------------
  describe "terminated session" do
    it "returns 401 after the session has been destroyed via logout" do
      session = create(:session, user: user)
      token = session.token

      # First request succeeds
      get "/api/v1/users/me", headers: bearer_header(token)
      expect(response).to have_http_status(:ok)

      # Simulate logout by destroying the session (same as terminate_session)
      session.destroy!

      # Second request with same token fails
      get "/api/v1/users/me", headers: bearer_header(token)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Multiple sessions: logging in twice creates separate sessions, both valid
  # ---------------------------------------------------------------------------
  describe "multiple sessions" do
    it "allows concurrent sessions for the same user" do
      session_a = create(:session, user: user)
      session_b = create(:session, user: user)

      expect(session_a.token).not_to eq(session_b.token)

      # Both tokens are valid
      get "/api/v1/users/me", headers: bearer_header(session_a.token)
      expect(response).to have_http_status(:ok)

      get "/api/v1/users/me", headers: bearer_header(session_b.token)
      expect(response).to have_http_status(:ok)
    end

    it "keeps other sessions valid when one is terminated" do
      session_a = create(:session, user: user)
      session_b = create(:session, user: user)

      session_a.destroy!

      get "/api/v1/users/me", headers: bearer_header(session_a.token)
      expect(response).to have_http_status(:unauthorized)

      get "/api/v1/users/me", headers: bearer_header(session_b.token)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # 10. User deletion: cascades to session invalidation
  # ---------------------------------------------------------------------------
  describe "user deletion cascading to sessions" do
    it "invalidates all sessions when the user is destroyed" do
      session = create(:session, user: user)
      token = session.token

      # Confirm session works first
      get "/api/v1/users/me", headers: bearer_header(token)
      expect(response).to have_http_status(:ok)

      # Destroy user (has_many :sessions, dependent: :destroy)
      user.destroy!

      expect(Session.find_by(token: token)).to be_nil

      get "/api/v1/users/me", headers: bearer_header(token)
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
