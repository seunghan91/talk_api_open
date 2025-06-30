require 'rails_helper'

RSpec.describe Broadcasts::RecipientSelectionService do
  let(:sender) { create(:user) }
  let(:service) { described_class.new(sender) }

  # 테스트용 사용자 생성
  let!(:active_users) { create_list(:user, 10, status: :active, verified: true) }
  let!(:suspended_user) { create(:user, status: :suspended) }
  let!(:unverified_user) { create(:user, verified: false) }
  let!(:blocked_user) { create(:user, status: :active) }

  before do
    # 차단 관계 설정
    create(:block, blocker: sender, blocked: blocked_user)
  end

  describe '#select_recipients' do
    context '기본 선택 전략' do
      it '요청한 수만큼 수신자를 선택한다' do
        recipients = service.select_recipients(count: 5)
        expect(recipients.count).to eq(5)
      end

      it '활성 상태의 사용자만 선택한다' do
        recipients = service.select_recipients(count: 5)
        expect(recipients).to all(have_attributes(status: 'active'))
      end

      it '인증된 사용자만 선택한다' do
        recipients = service.select_recipients(count: 5)
        expect(recipients).to all(have_attributes(verified: true))
      end

      it '발신자를 제외한다' do
        recipients = service.select_recipients(count: 5)
        expect(recipients).not_to include(sender)
      end

      it '차단한 사용자를 제외한다' do
        recipients = service.select_recipients(count: 10)
        expect(recipients).not_to include(blocked_user)
      end

      it '차단당한 사용자를 제외한다' do
        create(:block, blocker: active_users.first, blocked: sender)
        recipients = service.select_recipients(count: 10)
        expect(recipients).not_to include(active_users.first)
      end
    end

    context '사용 가능한 사용자가 부족할 때' do
      it '가능한 모든 사용자를 반환한다' do
        recipients = service.select_recipients(count: 20)
        # active_users(10) - blocked_user(1) = 9명
        expect(recipients.count).to eq(9)
      end
    end

    context '활동 기반 선택 전략' do
      before do
        # 일부 사용자에게 최근 활동 기록 추가
        active_users[0..2].each do |user|
          user.update(last_login_at: 1.hour.ago)
        end

        active_users[3..5].each do |user|
          user.update(last_login_at: 1.week.ago)
        end

        active_users[6..9].each do |user|
          user.update(last_login_at: 1.month.ago)
        end
      end

      it '최근 활동한 사용자를 우선 선택한다' do
        service_with_strategy = described_class.new(
          sender,
          strategy: :activity_based
        )
        recipients = service_with_strategy.select_recipients(count: 3)

        # 최근 1시간 내 로그인한 사용자들이 선택되어야 함
        expect(recipients.map(&:last_login_at).compact.min).to be > 2.hours.ago
      end
    end

    context '관계 기반 선택 전략' do
      before do
        # 일부 사용자와 대화 이력 생성
        active_users[0..2].each do |user|
          conversation = create(:conversation, user_a: sender, user_b: user)
          create_list(:message, 5, conversation: conversation, sender: sender)
        end
      end

      it '대화 이력이 있는 사용자를 우선 선택한다' do
        service_with_strategy = described_class.new(
          sender,
          strategy: :relationship_based
        )
        recipients = service_with_strategy.select_recipients(count: 5)

        # 대화 이력이 있는 사용자가 포함되어야 함
        users_with_history = active_users[0..2]
        expect(recipients & users_with_history).not_to be_empty
      end
    end

    context '랜덤 선택 전략' do
      it '매번 다른 사용자를 선택한다' do
        results = 5.times.map do
          service.select_recipients(count: 3).map(&:id).sort
        end

        # 최소한 일부는 다른 결과여야 함
        expect(results.uniq.count).to be > 1
      end
    end
  end

  describe '#with_filters' do
    it '성별 필터를 적용한다' do
      male_users = active_users[0..4]
      female_users = active_users[5..9]

      male_users.each { |u| u.update(gender: :male) }
      female_users.each { |u| u.update(gender: :female) }

      service_with_filter = described_class.new(sender)
      recipients = service_with_filter
        .with_filters(gender: :female)
        .select_recipients(count: 3)

      expect(recipients).to all(have_attributes(gender: 'female'))
    end

    it '연령대 필터를 적용한다' do
      active_users[0..4].each { |u| u.update(age_group: '20s') }
      active_users[5..9].each { |u| u.update(age_group: '30s') }

      service_with_filter = described_class.new(sender)
      recipients = service_with_filter
        .with_filters(age_group: '20s')
        .select_recipients(count: 3)

      expect(recipients).to all(have_attributes(age_group: '20s'))
    end

    it '지역 필터를 적용한다' do
      active_users[0..4].each { |u| u.update(region: '서울') }
      active_users[5..9].each { |u| u.update(region: '부산') }

      service_with_filter = described_class.new(sender)
      recipients = service_with_filter
        .with_filters(region: '서울')
        .select_recipients(count: 3)

      expect(recipients).to all(have_attributes(region: '서울'))
    end
  end

  describe '의존성 주입' do
    it '커스텀 쿼리 빌더를 주입받을 수 있다' do
      custom_query_builder = double('QueryBuilder')
      allow(custom_query_builder).to receive(:eligible_recipients)
        .and_return(User.where(id: active_users[0..2].map(&:id)))

      service_with_injection = described_class.new(
        sender,
        query_builder: custom_query_builder
      )

      recipients = service_with_injection.select_recipients(count: 5)
      expect(recipients.count).to eq(3)
    end
  end
end
