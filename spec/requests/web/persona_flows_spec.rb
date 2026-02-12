require "rails_helper"

RSpec.describe "Web Persona Flows", type: :request do
  def inertia_component_from(response)
    # Inertia page payload is embedded as JSON in the HTML response.
    match = response.body.match(/(?:\"|&quot;)component(?:\"|&quot;)\s*:\s*(?:\"|&quot;)([^\"&]+)(?:\"|&quot;)/)
    match && match[1]
  end

  describe "Persona: Guest Visitor" do
    it "redirects to login when visiting home" do
      get "/"

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("/auth/login")
    end
  end

  describe "Persona: New User Onboarding" do
    let(:phone_number) { "01098765432" }

    it "goes through login -> verify -> register screens" do
      get "/auth/login"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Auth/Login")

      post "/auth/login", params: { phone_number: phone_number }
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("/auth/verify")

      get "/auth/verify"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Auth/Verify")

      # In test env, beta code shortcut is supported by service.
      post "/auth/verify", params: { code: "111111" }
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("/auth/register")

      get "/auth/register"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Auth/Register")
    end
  end

  describe "Persona: Existing Active User" do
    let!(:user) do
      create(
        :user,
        phone_number: "01012341234",
        password: "test1234",
        password_confirmation: "test1234",
        verified: true
      )
    end

    let!(:broadcast) { create(:broadcast, user: create(:user)) }
    let!(:recipient) { create(:broadcast_recipient, user: user, broadcast: broadcast) }

    it "logs in and can access home/broadcasts/conversations/profile/settings/notifications pages" do
      post "/auth/login", params: { phone_number: user.phone_number }
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("/auth/verify")

      post "/auth/verify", params: { code: "111111" }
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("/")

      get "/"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Home/Index")

      get "/broadcasts"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Broadcasts/Index")

      get "/conversations"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Conversations/Index")

      get "/profile"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Profile/Show")

      get "/settings"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Settings/Index")

      get "/notifications"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Notifications/Index")
    end
  end

  describe "Persona: Admin Auditor" do
    let!(:reported_user) { create(:user, phone_number: "01055556666") }
    let!(:reporter_user) { create(:user, phone_number: "01077778888") }
    let!(:report) { create(:report, reported: reported_user, reporter: reporter_user, reason: "abuse") }

    it "can access admin pages and perform report/user actions" do
      get "/admin"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Admin/Dashboard")

      get "/admin/reports"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Admin/Reports")

      put "/admin/reports/#{report.id}/process"
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("/admin/reports")

      get "/admin/users"
      expect(response).to have_http_status(:ok)
      expect(inertia_component_from(response)).to eq("Admin/Users")

      put "/admin/users/#{reported_user.id}/suspend", params: { duration: 3, reason: "policy violation" }
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("/admin/users")

      put "/admin/users/#{reported_user.id}/unsuspend"
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to("/admin/users")
    end
  end
end

