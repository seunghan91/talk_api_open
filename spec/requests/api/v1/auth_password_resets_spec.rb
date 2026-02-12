require "rails_helper"

RSpec.describe "Api::V1::Auth::PasswordResets", type: :request do
  let!(:user) { create(:user, phone_number: "01012345678", password: "oldpass123") }
  let!(:verification) do
    create(
      :phone_verification,
      phone_number: user.phone_number,
      code: "654321",
      verified: true,
      expires_at: 10.minutes.from_now
    )
  end

  describe "POST /api/v1/auth/password_resets" do
    it "resets password with valid verification data" do
      post "/api/v1/auth/password_resets", params: {
        user: {
          phone_number: user.phone_number,
          code: "654321",
          password: "newpass123",
          password_confirmation: "newpass123"
        }
      }

      expect(response).to have_http_status(:ok)
      expect(user.reload.authenticate("newpass123")).to be_truthy
      expect(PhoneVerification.where(id: verification.id)).to be_empty
    end

    it "returns unprocessable entity for invalid code" do
      post "/api/v1/auth/password_resets", params: {
        user: {
          phone_number: user.phone_number,
          code: "000000",
          password: "newpass123"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
