# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Broadcast Settings API", type: :request do
  before do
    # id=1 사용자는 자동 관리자이므로 더미 사용자로 소모
    create(:user) unless User.exists?(id: 1)
    SystemSetting.find_by(setting_key: "broadcast_limits")&.destroy
    create(:system_setting, :broadcast_limits)
  end

  # ═══════════════════════════════════════════════
  # GET /api/v1/admin/broadcast_settings
  # ═══════════════════════════════════════════════
  describe "GET /api/v1/admin/broadcast_settings" do
    context "페르소나: 인증되지 않은 사용자" do
      it "401 Unauthorized를 반환" do
        get "/api/v1/admin/broadcast_settings"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "페르소나: 일반 사용자 (비관리자)" do
      let(:user) { create(:user, is_admin: false) }

      it "403 Forbidden을 반환" do
        get "/api/v1/admin/broadcast_settings", headers: auth_headers_for(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "페르소나: 관리자" do
      let(:admin) { create(:user, is_admin: true) }

      it "현재 브로드캐스트 제한 설정을 반환" do
        get "/api/v1/admin/broadcast_settings", headers: auth_headers_for(admin)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["daily_limit"]).to eq(20)
        expect(json["hourly_limit"]).to eq(5)
        expect(json["cooldown_minutes"]).to eq(10)
        expect(json["bypass_roles"]).to eq(["admin"])
      end
    end
  end

  # ═══════════════════════════════════════════════
  # PATCH /api/v1/admin/broadcast_settings
  # ═══════════════════════════════════════════════
  describe "PATCH /api/v1/admin/broadcast_settings" do
    context "페르소나: 일반 사용자 (비관리자)" do
      let(:user) { create(:user, is_admin: false) }

      it "403 Forbidden을 반환" do
        patch "/api/v1/admin/broadcast_settings",
              params: { daily_limit: 50 },
              headers: auth_headers_for(user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "페르소나: 관리자" do
      let(:admin) { create(:user, is_admin: true) }

      it "일일 제한을 업데이트" do
        patch "/api/v1/admin/broadcast_settings",
              params: { daily_limit: 50 },
              headers: auth_headers_for(admin)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["settings"]["daily_limit"]).to eq(50)
        expect(json["updated_by"]).to eq(admin.nickname)
      end

      it "시간당 제한을 업데이트" do
        patch "/api/v1/admin/broadcast_settings",
              params: { hourly_limit: 10 },
              headers: auth_headers_for(admin)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["settings"]["hourly_limit"]).to eq(10)
      end

      it "쿨다운을 업데이트" do
        patch "/api/v1/admin/broadcast_settings",
              params: { cooldown_minutes: 15 },
              headers: auth_headers_for(admin)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["settings"]["cooldown_minutes"]).to eq(15)
      end

      it "여러 설정을 동시에 업데이트" do
        patch "/api/v1/admin/broadcast_settings",
              params: { daily_limit: 50, hourly_limit: 10, cooldown_minutes: 15 },
              headers: auth_headers_for(admin)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["settings"]["daily_limit"]).to eq(50)
        expect(json["settings"]["hourly_limit"]).to eq(10)
        expect(json["settings"]["cooldown_minutes"]).to eq(15)
      end

      it "업데이트 후 실제 설정이 DB에 반영됨" do
        patch "/api/v1/admin/broadcast_settings",
              params: { daily_limit: 100 },
              headers: auth_headers_for(admin)

        expect(SystemSetting.broadcast_limits["daily_limit"]).to eq(100)
      end

      it "updated_by가 관리자로 기록됨" do
        patch "/api/v1/admin/broadcast_settings",
              params: { daily_limit: 50 },
              headers: auth_headers_for(admin)

        setting = SystemSetting.find_by(setting_key: "broadcast_limits")
        expect(setting.updated_by).to eq(admin)
      end

      context "유효하지 않은 값" do
        it "일일 제한이 0이면 422 에러" do
          patch "/api/v1/admin/broadcast_settings",
                params: { daily_limit: 0 },
                headers: auth_headers_for(admin)

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "시간당 제한이 일일 제한보다 크면 422 에러" do
          patch "/api/v1/admin/broadcast_settings",
                params: { hourly_limit: 100 },
                headers: auth_headers_for(admin)

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "쿨다운이 음수이면 422 에러" do
          patch "/api/v1/admin/broadcast_settings",
                params: { cooldown_minutes: -5 },
                headers: auth_headers_for(admin)

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end
end
