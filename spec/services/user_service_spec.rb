require 'rails_helper'

RSpec.describe UserService do
  let(:user) { create(:user) }
  let(:service) { described_class.new }

  describe '#create_user' do
    let(:valid_params) do
      {
        phone_number: '01012345678',
        password: 'password123',
        nickname: '테스트유저',
        gender: 'male'
      }
    end

    context '유효한 파라미터로 호출할 때' do
      it '사용자를 생성한다' do
        expect {
          result = service.create_user(valid_params)
          expect(result.success?).to be true
          expect(result.user).to be_persisted
          expect(result.user.phone_number).to eq(valid_params[:phone_number])
        }.to change(User, :count).by(1)
      end

      it '지갑을 자동으로 생성한다' do
        result = service.create_user(valid_params)
        expect(result.user.wallet).to be_present
        expect(result.user.wallet.balance).to eq(0)
      end

      it 'welcome 알림을 생성한다' do
        expect_any_instance_of(NotificationService).to receive(:send_notification)
        service.create_user(valid_params)
      end
    end

    context '유효하지 않은 전화번호일 때' do
      it '실패 Result를 반환한다' do
        invalid_params = valid_params.merge(phone_number: '123')
        result = service.create_user(invalid_params)

        expect(result.success?).to be false
        expect(result.error).to include('전화번호')
      end
    end

    context '중복된 전화번호일 때' do
      before { create(:user, phone_number: valid_params[:phone_number]) }

      it '실패 Result를 반환한다' do
        result = service.create_user(valid_params)
        expect(result.success?).to be false
        expect(result.error).to include('이미 사용 중')
      end
    end
  end

  describe '#suspend_user' do
    let(:reason) { '부적절한 콘텐츠' }
    let(:duration_days) { 7 }

    it '사용자를 정지시킨다', :truncation do
      result = service.suspend_user(user, reason: reason, duration_days: duration_days)

      expect(result.success?).to be true
      expect(result.user.status).to eq('suspended')

      # 정지 기록 확인
      suspension = user.user_suspensions.last
      expect(suspension).to be_present
      expect(suspension.reason).to eq(reason)
      expect(suspension.active).to be true
    end

    it '정지 알림을 전송한다' do
      expect_any_instance_of(NotificationService).to receive(:send_notification)
      service.suspend_user(user, reason: reason, duration_days: duration_days)
    end

    it '정지 해제 작업을 스케줄링한다' do
      expect(ExpiredSuspensionJob).to receive_message_chain(:set, :perform_later)
      service.suspend_user(user, reason: reason, duration_days: duration_days)
    end
  end

  describe '#block_user' do
    let(:blocked_user) { create(:user) }

    it '사용자를 차단한다' do
      result = service.block_user(blocker: user, blocked: blocked_user)

      expect(result.success?).to be true
      expect(Block.exists?(blocker: user, blocked: blocked_user)).to be true
    end

    it '중복 차단을 방지한다' do
      service.block_user(blocker: user, blocked: blocked_user)
      result = service.block_user(blocker: user, blocked: blocked_user)

      expect(result.success?).to be false
      expect(result.error).to include('이미 차단')
    end

    it '자기 자신은 차단할 수 없다' do
      result = service.block_user(blocker: user, blocked: user)

      expect(result.success?).to be false
      expect(result.error).to include('자기 자신')
    end
  end

  describe '#report_user' do
    let(:reported_user) { create(:user) }
    let(:report_params) do
      {
        reporter: user,
        reported: reported_user,
        reason: 'spam'
      }
    end

    it '신고를 생성한다' do
      expect {
        result = service.report_user(**report_params)
        expect(result.success?).to be true
        expect(result.report).to be_persisted
      }.to change(Report, :count).by(1)
    end

    it '3회 이상 신고 시 자동 정지', :truncation do
      # 이미 2회 신고된 상태
      2.times do
        create(:report, reported: reported_user, status: :resolved)
      end

      result = service.report_user(**report_params)
      expect(result.success?).to be true
      expect(result.user.status).to eq('suspended')
    end
  end

  describe '#update_profile' do
    let(:update_params) do
      {
        nickname: '새닉네임',
        age_group: '30s',
        region: '서울'
      }
    end

    it '프로필을 업데이트한다' do
      result = service.update_profile(user, update_params)

      expect(result.success?).to be true
      expect(user.reload.nickname).to eq('새닉네임')
      expect(user.age_group).to eq('30s')
      expect(user.profile_completed).to be true
    end

    it '금지된 닉네임은 거부한다' do
      result = service.update_profile(user, nickname: '관리자')

      expect(result.success?).to be false
      expect(result.error).to include('사용할 수 없는 닉네임')
    end
  end

  describe '#check_suspension_expiry' do
    let!(:expired_suspension) do
      create(:user_suspension,
        user: user,
        suspended_until: 1.day.ago,
        active: true
      )
    end

    before { user.update(status: :suspended) }

    it '만료된 정지를 해제한다', :truncation do
      result = service.check_suspension_expiry(user)

      expect(result.success?).to be true
      expect(result.user.status).to eq('active')

      # 정지 기록 확인
      expired_suspension.reload
      expect(expired_suspension.active).to be false
    end
  end

  describe '의존성 주입' do
    it '커스텀 알림 서비스를 주입받을 수 있다' do
      mock_notification_service = double('NotificationService')
      service_with_injection = described_class.new(
        notification_service: mock_notification_service
      )

      expect(mock_notification_service).to receive(:send_notification)

      service_with_injection.create_user(
        phone_number: '01012345678',
        password: 'password123',
        nickname: '테스트'
      )
    end
  end
end
