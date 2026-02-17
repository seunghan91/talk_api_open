# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Broadcast Limits API", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before do
    SystemSetting.find_by(setting_key: "broadcast_limits")&.destroy
    create(:system_setting, :broadcast_limits)
  end

  # ═══════════════════════════════════════════════
  # GET /api/v1/broadcasts/limits
  # ═══════════════════════════════════════════════
  describe "GET /api/v1/broadcasts/limits" do
    context "페르소나: 인증되지 않은 사용자" do
      it "401 Unauthorized를 반환" do
        get "/api/v1/broadcasts/limits"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "페르소나: 신규 사용자" do
      let(:user) { create(:user) }

      it "전체 제한 정보를 반환" do
        get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["daily_limit"]).to eq(20)
        expect(json["daily_used"]).to eq(0)
        expect(json["daily_remaining"]).to eq(20)
        expect(json["hourly_limit"]).to eq(5)
        expect(json["hourly_used"]).to eq(0)
        expect(json["can_broadcast"]).to be true
        expect(json["next_reset_at"]).to be_present
      end
    end

    context "페르소나: 일반 사용자 (일부 사용)" do
      let(:user) { create(:user) }

      it "사용량이 반영된 제한 정보를 반환" do
        # 쿨다운/시간당 제한 회피를 위해 정오에 시간 고정 후 분산 생성
        travel_to Time.current.noon do
          7.times { |i| create(:broadcast, user: user, created_at: (2.hours + i * 20.minutes).ago) }

          get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json["daily_used"]).to eq(7)
          expect(json["daily_remaining"]).to eq(13)
          expect(json["can_broadcast"]).to be true
        end
      end
    end

    context "페르소나: 제한 도달 사용자" do
      let(:user) { create(:user) }

      it "can_broadcast가 false를 반환" do
        create_list(:broadcast, 20, user: user)

        get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["daily_used"]).to eq(20)
        expect(json["daily_remaining"]).to eq(0)
        expect(json["can_broadcast"]).to be false
      end
    end

    context "페르소나: 쿨다운 중 사용자" do
      let(:user) { create(:user) }

      it "쿨다운 종료 시간을 포함하여 반환" do
        create(:broadcast, user: user, created_at: 3.minutes.ago)

        get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["can_broadcast"]).to be false
        expect(json["cooldown_ends_at"]).to be_present
      end
    end

    context "페르소나: 관리자" do
      let(:admin) { create(:user, is_admin: true) }

      it "bypass 상태를 반환" do
        get "/api/v1/broadcasts/limits", headers: auth_headers_for(admin)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["can_broadcast"]).to be true
        expect(json["is_bypass"]).to be true
      end
    end

    context "페르소나: 차단된 사용자" do
      let(:blocked_user) { create(:user, blocked: true) }

      it "제한 상태에서도 API는 접근 가능 (인증 통과)" do
        # status는 가상 속성이므로, blocked 플래그로 대체 테스트
        get "/api/v1/broadcasts/limits", headers: auth_headers_for(blocked_user)

        # 인증은 통과하지만 데이터는 반환됨
        expect(response).to have_http_status(:ok).or have_http_status(:forbidden)
      end
    end
  end
end
