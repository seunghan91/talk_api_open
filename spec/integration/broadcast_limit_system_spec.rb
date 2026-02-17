# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Broadcast Limit System - 통합 테스트", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before do
    SystemSetting.find_by(setting_key: "broadcast_limits")&.destroy
    create(:system_setting, :broadcast_limits)
  end

  # ═══════════════════════════════════════════════════════════════
  # 페르소나 1: 일반 사용자 - 전체 플로우
  # 제한 조회 -> 브로드캐스트 전송 -> 제한 상태 변경 확인
  # ═══════════════════════════════════════════════════════════════
  context "페르소나: 일반 사용자 전체 플로우" do
    let(:user) { create(:user, is_admin: false) }

    it "제한 조회 후 상태가 정확히 반영됨" do
      travel_to Time.current.noon do
        # Step 1: 초기 제한 상태 조회
        get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["daily_used"]).to eq(0)
        expect(json["daily_remaining"]).to eq(20)
        expect(json["can_broadcast"]).to be true

        # Step 2: 브로드캐스트 5개 생성 (쿨다운/시간당 회피)
        5.times { |i| create(:broadcast, user: user, created_at: (2.hours + i * 20.minutes).ago) }

        # Step 3: 제한 상태 다시 조회 - 사용량 반영 확인
        get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)
        json = JSON.parse(response.body)
        expect(json["daily_used"]).to eq(5)
        expect(json["daily_remaining"]).to eq(15)
        expect(json["can_broadcast"]).to be true
      end
    end

    it "일일 제한 도달 후 다음 날 리셋됨" do
      create_list(:broadcast, 20, user: user)

      # 오늘: 전송 불가
      get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)
      json = JSON.parse(response.body)
      expect(json["can_broadcast"]).to be false

      # 다음 날: 전송 가능
      travel_to 1.day.from_now do
        get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)
        json = JSON.parse(response.body)
        expect(json["can_broadcast"]).to be true
        expect(json["daily_used"]).to eq(0)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════
  # 페르소나 2: 관리자 - 설정 변경 후 일반 사용자에게 영향
  # ═══════════════════════════════════════════════════════════════
  context "페르소나: 관리자가 설정 변경 후 사용자에게 영향" do
    let(:admin) { create(:user, is_admin: true) }
    let(:user) { create(:user, is_admin: false) }

    it "관리자가 일일 제한을 낮추면 기존 사용자에게 즉시 적용" do
      travel_to Time.current.noon do
        # 사용자가 10개 보냄 (쿨다운/시간당 회피)
        10.times { |i| create(:broadcast, user: user, created_at: (2.hours + i * 15.minutes).ago) }

        # 아직 전송 가능 (기본 제한: 20)
        get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)
        json = JSON.parse(response.body)
        expect(json["can_broadcast"]).to be true

      # 관리자가 제한을 5로 변경
      patch "/api/v1/admin/broadcast_settings",
            params: { daily_limit: 5, hourly_limit: 3 },
            headers: auth_headers_for(admin)
      expect(response).to have_http_status(:ok)

        # 사용자는 이제 전송 불가 (10 >= 5)
        get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)
        json = JSON.parse(response.body)
        expect(json["can_broadcast"]).to be false
        expect(json["daily_limit"]).to eq(5)
        expect(json["daily_used"]).to eq(10)
      end
    end

    it "관리자 본인은 제한 우회 가능" do
      # 관리자가 엄격한 제한 설정
      patch "/api/v1/admin/broadcast_settings",
            params: { daily_limit: 1 },
            headers: auth_headers_for(admin)

      # 관리자가 브로드캐스트 많이 보냄
      create_list(:broadcast, 10, user: admin)

      # 관리자는 여전히 전송 가능
      get "/api/v1/broadcasts/limits", headers: auth_headers_for(admin)
      json = JSON.parse(response.body)
      expect(json["can_broadcast"]).to be true
      expect(json["is_bypass"]).to be true
    end

    it "관리자가 설정을 조회하고 변경하는 전체 플로우" do
      # Step 1: 현재 설정 조회
      get "/api/v1/admin/broadcast_settings", headers: auth_headers_for(admin)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["daily_limit"]).to eq(20)

      # Step 2: 설정 변경
      patch "/api/v1/admin/broadcast_settings",
            params: { daily_limit: 50, hourly_limit: 10, cooldown_minutes: 5 },
            headers: auth_headers_for(admin)
      expect(response).to have_http_status(:ok)

      # Step 3: 변경된 설정 확인
      get "/api/v1/admin/broadcast_settings", headers: auth_headers_for(admin)
      json = JSON.parse(response.body)
      expect(json["daily_limit"]).to eq(50)
      expect(json["hourly_limit"]).to eq(10)
      expect(json["cooldown_minutes"]).to eq(5)
    end
  end

  # ═══════════════════════════════════════════════════════════════
  # 페르소나 3: 쿨다운 시나리오 (시간 경과 테스트)
  # ═══════════════════════════════════════════════════════════════
  context "페르소나: 쿨다운 시나리오" do
    let(:user) { create(:user, is_admin: false) }

    it "브로드캐스트 후 쿨다운 -> 시간 경과 후 다시 전송 가능" do
      # Step 1: 브로드캐스트 전송
      create(:broadcast, user: user, created_at: Time.current)

      # Step 2: 즉시 제한 상태 확인 - 쿨다운 중
      get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)
      json = JSON.parse(response.body)
      expect(json["can_broadcast"]).to be false
      expect(json["cooldown_ends_at"]).to be_present

      # Step 3: 10분 경과 후 - 쿨다운 해제
      travel_to 11.minutes.from_now do
        get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)
        json = JSON.parse(response.body)
        expect(json["can_broadcast"]).to be true
        expect(json["cooldown_ends_at"]).to be_nil
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════
  # 페르소나 4: 시간당 제한 시나리오
  # ═══════════════════════════════════════════════════════════════
  context "페르소나: 시간당 제한 시나리오" do
    let(:user) { create(:user, is_admin: false) }

    before do
      # 쿨다운 비활성화 (시간당 제한만 테스트)
      SystemSetting.find_by(setting_key: "broadcast_limits")&.destroy
      create(:system_setting, :no_cooldown)
    end

    it "1시간 내 5회 전송 후 시간 경과 시 다시 가능" do
      # 50분 전부터 5개 보냄
      5.times do |i|
        create(:broadcast, user: user, created_at: (50 - i * 5).minutes.ago)
      end

      # 현재: 시간당 제한 초과
      get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)
      json = JSON.parse(response.body)
      expect(json["can_broadcast"]).to be false

      # 1시간 후: 시간당 제한 해제
      travel_to 1.hour.from_now do
        get "/api/v1/broadcasts/limits", headers: auth_headers_for(user)
        json = JSON.parse(response.body)
        expect(json["can_broadcast"]).to be true
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════
  # 페르소나 5: 비관리자 사용자의 관리자 기능 접근 불가
  # (status는 가상 속성으로 DB에 저장되지 않아 suspended 테스트는 서비스 레벨에서 수행)
  # ═══════════════════════════════════════════════════════════════
  context "페르소나: 비관리자 사용자" do
    let(:normal_user) { create(:user, is_admin: false) }

    before do
      # id=1이 관리자가 되지 않도록 보장
      create(:user) unless User.exists?(id: 1)
    end

    it "관리자 설정 접근 불가" do
      get "/api/v1/admin/broadcast_settings", headers: auth_headers_for(normal_user)
      expect(response).to have_http_status(:forbidden)
    end

    it "관리자 설정 변경 불가" do
      patch "/api/v1/admin/broadcast_settings",
            params: { daily_limit: 100 },
            headers: auth_headers_for(normal_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ═══════════════════════════════════════════════════════════════
  # 페르소나 6: 동시성 시나리오 (사용량 로그)
  # ═══════════════════════════════════════════════════════════════
  context "페르소나: 사용량 로그 기록" do
    let(:user) { create(:user, is_admin: false) }

    it "제한 초과 시도가 usage_log에 기록됨" do
      travel_to Time.current.noon do
        # 시간 분산하여 시간당/쿨다운 회피
        20.times { |i| create(:broadcast, user: user, created_at: (2.hours + i * 15.minutes).ago) }

        # 제한 초과 상태에서 여러 번 조회
        3.times do
          service = Broadcasts::LimitService.new
          service.check_limit(user)
        end

        log = BroadcastUsageLog.today_for(user)
        expect(log).to be_present
        expect(log.limit_exceeded_count).to eq(3)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════
  # 페르소나 7: 복합 제한 시나리오
  # ═══════════════════════════════════════════════════════════════
  context "페르소나: 복합 제한 시나리오" do
    let(:user) { create(:user, is_admin: false) }

    it "일일 제한과 시간당 제한 중 먼저 도달하는 것이 적용" do
      # strict 설정: daily 3, hourly 2, cooldown 5분
      SystemSetting.find_by(setting_key: "broadcast_limits")&.destroy
      create(:system_setting, :strict_limits)

      # 2개 보냄 (20분 간격으로, 쿨다운 5분 회피)
      create(:broadcast, user: user, created_at: 20.minutes.ago)
      create(:broadcast, user: user, created_at: 10.minutes.ago)

      # hourly limit(2) 도달 - 시간당 제한이 먼저
      service = Broadcasts::LimitService.new
      result = service.check_limit(user)

      # 쿨다운(5분) 또는 시간당 제한(2)이 걸릴 수 있음
      expect(result.can_broadcast?).to be false
    end
  end
end
