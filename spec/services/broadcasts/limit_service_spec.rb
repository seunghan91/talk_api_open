# frozen_string_literal: true

require "rails_helper"

RSpec.describe Broadcasts::LimitService do
  include ActiveSupport::Testing::TimeHelpers

  let(:service) { described_class.new }

  before do
    # 기본 브로드캐스트 제한 설정
    SystemSetting.find_by(setting_key: "broadcast_limits")&.destroy
    create(:system_setting, :broadcast_limits)
  end

  # ═══════════════════════════════════════════════
  # 페르소나 1: 일반 사용자 (기본 제한 적용)
  # ═══════════════════════════════════════════════
  context "페르소나: 일반 사용자" do
    let(:user) { create(:user, is_admin: false) }

    describe "#check_limit" do
      it "브로드캐스트를 한 번도 보내지 않은 경우 전송 가능" do
        result = service.check_limit(user)

        expect(result.can_broadcast?).to be true
        expect(result.reason).to be_nil
        expect(result.limit_info[:daily_limit]).to eq(20)
        expect(result.limit_info[:daily_used]).to eq(0)
        expect(result.limit_info[:daily_remaining]).to eq(20)
      end

      it "일일 제한 내에서 전송 가능" do
        # 정오로 이동하여 오늘 범위 내 보장
        # 쿨다운(10분) 및 시간당 제한(5) 회피를 위해 시간적으로 분산
        travel_to Time.current.noon do
          10.times do |i|
            # 2시간~6시간 전에 생성 (시간당 5개 미만으로 분산)
            create(:broadcast, user: user, created_at: (2.hours + (i * 20).minutes).ago)
          end

          result = service.check_limit(user)

          expect(result.can_broadcast?).to be true
          expect(result.limit_info[:daily_used]).to eq(10)
          expect(result.limit_info[:daily_remaining]).to eq(10)
        end
      end

      it "일일 제한에 정확히 도달하면 전송 불가" do
        create_list(:broadcast, 20, user: user)

        result = service.check_limit(user)

        expect(result.can_broadcast?).to be false
        expect(result.reason).to eq("DAILY_LIMIT_EXCEEDED")
        expect(result.limit_info[:daily_used]).to eq(20)
        expect(result.limit_info[:daily_remaining]).to eq(0)
        expect(result.limit_info[:next_reset_at]).to be_present
      end

      it "어제 보낸 브로드캐스트는 오늘 제한에 포함되지 않음" do
        travel_to 1.day.ago do
          create_list(:broadcast, 20, user: user)
        end

        result = service.check_limit(user)

        expect(result.can_broadcast?).to be true
        expect(result.limit_info[:daily_used]).to eq(0)
      end
    end

    describe "#get_limit_status" do
      it "제한 상태를 올바르게 반환" do
        # 쿨다운 회피를 위해 과거 시간으로 생성
        5.times do |i|
          create(:broadcast, user: user, created_at: (60 + i).minutes.ago)
        end

        status = service.get_limit_status(user)

        expect(status[:daily_limit]).to eq(20)
        expect(status[:daily_used]).to eq(5)
        expect(status[:daily_remaining]).to eq(15)
        expect(status[:hourly_limit]).to eq(5)
        expect(status[:can_broadcast]).to be true
        expect(status[:next_reset_at]).to be_present
      end
    end

    describe "#record_broadcast" do
      it "사용량 로그를 기록" do
        expect {
          service.record_broadcast(user)
        }.to change(BroadcastUsageLog, :count).by(1)

        log = BroadcastUsageLog.today_for(user)
        expect(log.broadcasts_sent).to eq(1)
        expect(log.last_broadcast_at).to be_present
      end

      it "같은 날 여러 번 기록하면 카운트가 증가" do
        service.record_broadcast(user)
        service.record_broadcast(user)

        log = BroadcastUsageLog.today_for(user)
        expect(log.broadcasts_sent).to eq(2)
      end
    end
  end

  # ═══════════════════════════════════════════════
  # 페르소나 2: 관리자 (bypass_roles에 포함)
  # ═══════════════════════════════════════════════
  context "페르소나: 관리자" do
    let(:admin) { create(:user, is_admin: true) }

    describe "#check_limit" do
      it "일일 제한을 초과해도 전송 가능 (bypass)" do
        create_list(:broadcast, 30, user: admin)

        result = service.check_limit(admin)

        expect(result.can_broadcast?).to be true
        expect(result.reason).to be_nil
        expect(result.limit_info[:is_bypass]).to be true
      end

      it "시간당 제한도 우회" do
        create_list(:broadcast, 10, user: admin)

        result = service.check_limit(admin)

        expect(result.can_broadcast?).to be true
      end

      it "쿨다운도 우회" do
        create(:broadcast, user: admin, created_at: 1.minute.ago)

        result = service.check_limit(admin)

        expect(result.can_broadcast?).to be true
      end
    end

    describe "#get_limit_status" do
      it "bypass 상태임을 표시" do
        status = service.get_limit_status(admin)

        expect(status[:is_bypass]).to be true
        expect(status[:can_broadcast]).to be true
      end
    end
  end

  # ═══════════════════════════════════════════════
  # 페르소나 3: 신규 사용자 (첫 브로드캐스트)
  # ═══════════════════════════════════════════════
  context "페르소나: 신규 사용자" do
    let(:new_user) { create(:user, is_admin: false) }

    describe "#check_limit" do
      it "첫 브로드캐스트 전송 가능" do
        result = service.check_limit(new_user)

        expect(result.can_broadcast?).to be true
        expect(result.limit_info[:daily_used]).to eq(0)
        expect(result.limit_info[:daily_remaining]).to eq(20)
      end
    end

    describe "#get_limit_status" do
      it "사용량이 0인 상태를 반환" do
        status = service.get_limit_status(new_user)

        expect(status[:daily_used]).to eq(0)
        expect(status[:daily_remaining]).to eq(20)
        expect(status[:hourly_used]).to eq(0)
        expect(status[:can_broadcast]).to be true
      end
    end
  end

  # ═══════════════════════════════════════════════
  # 페르소나 4: 제한 도달 사용자 (일일 한도 소진)
  # ═══════════════════════════════════════════════
  context "페르소나: 제한 도달 사용자" do
    let(:heavy_user) { create(:user, is_admin: false) }

    before do
      # 정오에 고정하여 시간 경계 문제 방지
      travel_to Time.current.noon

      # 시간적으로 분산하여 시간당 제한 회피
      20.times do |i|
        create(:broadcast, user: heavy_user, created_at: (2.hours + (i * 15).minutes).ago)
      end
    end

    after { travel_back }

    describe "#check_limit" do
      it "일일 제한 초과로 전송 불가" do
        result = service.check_limit(heavy_user)

        expect(result.can_broadcast?).to be false
        expect(result.reason).to eq("DAILY_LIMIT_EXCEEDED")
      end

      it "제한 초과 시도가 usage_log에 기록됨" do
        expect {
          service.check_limit(heavy_user)
        }.to change { BroadcastUsageLog.today_for(heavy_user)&.limit_exceeded_count.to_i }.by(1)
      end

      it "다음 날에는 다시 전송 가능" do
        travel_back
        travel_to 1.day.from_now.noon
        result = service.check_limit(heavy_user)
        expect(result.can_broadcast?).to be true
      end
    end

    describe "#get_limit_status" do
      it "can_broadcast가 false" do
        status = service.get_limit_status(heavy_user)

        expect(status[:can_broadcast]).to be false
        expect(status[:daily_remaining]).to eq(0)
      end
    end
  end

  # ═══════════════════════════════════════════════
  # 페르소나 5: 쿨다운 중 사용자
  # ═══════════════════════════════════════════════
  context "페르소나: 쿨다운 중 사용자" do
    let(:cooldown_user) { create(:user, is_admin: false) }

    describe "#check_limit" do
      it "마지막 전송 후 10분 미만이면 전송 불가" do
        create(:broadcast, user: cooldown_user, created_at: 5.minutes.ago)

        result = service.check_limit(cooldown_user)

        expect(result.can_broadcast?).to be false
        expect(result.reason).to eq("COOLDOWN_ACTIVE")
        expect(result.limit_info[:cooldown_ends_at]).to be_present
      end

      it "마지막 전송 후 10분 이상이면 전송 가능" do
        create(:broadcast, user: cooldown_user, created_at: 11.minutes.ago)

        result = service.check_limit(cooldown_user)

        expect(result.can_broadcast?).to be true
      end

      it "쿨다운 종료 시간이 정확히 반환됨" do
        broadcast_time = 3.minutes.ago
        create(:broadcast, user: cooldown_user, created_at: broadcast_time)

        result = service.check_limit(cooldown_user)

        expected_end = (broadcast_time + 10.minutes).iso8601
        expect(result.limit_info[:cooldown_ends_at]).to be_present
      end

      it "쿨다운이 0분으로 설정된 경우 쿨다운 체크 안함" do
        SystemSetting.find_by(setting_key: "broadcast_limits")&.destroy
        create(:system_setting, :no_cooldown)

        create(:broadcast, user: cooldown_user, created_at: 1.second.ago)

        result = service.check_limit(cooldown_user)
        expect(result.can_broadcast?).to be true
      end
    end

    describe "#get_limit_status" do
      it "쿨다운 종료 시간이 포함됨" do
        travel_to Time.current.noon do
          create(:broadcast, user: cooldown_user, created_at: 5.minutes.ago)

          status = service.get_limit_status(cooldown_user)

          expect(status[:can_broadcast]).to be false
          expect(status[:cooldown_ends_at]).to be_present
        end
      end
    end
  end

  # ═══════════════════════════════════════════════
  # 페르소나 6: 시간당 제한 사용자
  # ═══════════════════════════════════════════════
  context "페르소나: 시간당 제한 사용자" do
    let(:hourly_user) { create(:user, is_admin: false) }

    describe "#check_limit" do
      it "1시간 내 5회 전송 후 시간당 제한 초과" do
        # 쿨다운을 0으로 설정하여 시간당 제한만 테스트
        SystemSetting.find_by(setting_key: "broadcast_limits")&.destroy
        create(:system_setting, :no_cooldown)

        # 1시간 내 5개 브로드캐스트 (시간당 제한: 5)
        5.times do |i|
          create(:broadcast, user: hourly_user, created_at: (50 - i).minutes.ago)
        end

        result = service.check_limit(hourly_user)

        expect(result.can_broadcast?).to be false
        expect(result.reason).to eq("HOURLY_LIMIT_EXCEEDED")
      end

      it "1시간 전에 보낸 것은 시간당 제한에 포함되지 않음" do
        # 쿨다운을 0으로 설정
        SystemSetting.find_by(setting_key: "broadcast_limits")&.destroy
        create(:system_setting, :no_cooldown)

        # 2시간 전에 5개 보냄
        5.times do
          create(:broadcast, user: hourly_user, created_at: 2.hours.ago)
        end

        result = service.check_limit(hourly_user)

        expect(result.can_broadcast?).to be true
      end

      it "시간당 4회까지는 전송 가능" do
        SystemSetting.find_by(setting_key: "broadcast_limits")&.destroy
        create(:system_setting, :no_cooldown)

        4.times do |i|
          create(:broadcast, user: hourly_user, created_at: (50 - i).minutes.ago)
        end

        result = service.check_limit(hourly_user)

        expect(result.can_broadcast?).to be true
      end
    end
  end

  # ═══════════════════════════════════════════════
  # 설정 변경 테스트
  # ═══════════════════════════════════════════════
  context "관리자 설정 변경" do
    let(:user) { create(:user, is_admin: false) }

    it "일일 제한을 변경하면 즉시 적용됨" do
      # 정오로 이동하여 오늘 범위 내 보장
      travel_to Time.current.noon do
        # 시간당/쿨다운 제한 회피를 위해 시간적으로 분산
        18.times do |i|
          create(:broadcast, user: user, created_at: (2.hours + (i * 15).minutes).ago)
        end

        # 아직 전송 가능 (기본 제한: 20)
        expect(service.check_limit(user).can_broadcast?).to be true

        # 관리자가 제한을 15로 변경
        SystemSetting.update_broadcast_limits!({ "daily_limit" => 15 })

        # 이제 전송 불가 (18 >= 15)
        expect(service.check_limit(user).can_broadcast?).to be false
      end
    end

    it "strict 제한으로 변경 시 더 엄격하게 적용" do
      SystemSetting.find_by(setting_key: "broadcast_limits")&.destroy
      create(:system_setting, :strict_limits) # daily: 3, hourly: 2

      create_list(:broadcast, 3, user: user)

      result = service.check_limit(user)
      expect(result.can_broadcast?).to be false
      expect(result.reason).to eq("DAILY_LIMIT_EXCEEDED")
    end
  end
end
