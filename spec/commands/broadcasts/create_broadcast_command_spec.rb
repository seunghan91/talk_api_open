# spec/commands/broadcasts/create_broadcast_command_spec.rb
require 'rails_helper'

RSpec.describe Broadcasts::CreateBroadcastCommand do
  let(:user) { create(:user, gender: 'male', status: :active) }
  let(:wallet) { user.wallet.tap { |w| w.update!(balance: 10000) } }
  let(:recipients) { create_list(:user, 3, gender: 'female', status: :active) }
  let(:audio_file) do
    fixture_file_upload(
      Rails.root.join('spec/fixtures/files/sample_audio.wav'),
      'audio/wav'
    )
  end

  # Mock 의존성
  let(:broadcast_repository) { instance_double(BroadcastRepository) }
  let(:recipient_selector) { instance_double(Broadcasts::RecipientSelector) }
  let(:event_publisher) { instance_double(EventPublisher) }

  subject(:command) do
    described_class.new(
      user: user,
      audio_file: audio_file,
      content: "테스트 브로드캐스트",
      recipient_count: 5,
      broadcast_repository: broadcast_repository,
      recipient_selector: recipient_selector,
      event_publisher: event_publisher
    )
  end

  before do
    # 기본 wallet 설정
    allow(user).to receive(:wallet).and_return(wallet)
    allow(wallet).to receive(:withdraw).and_return(true)

    # BroadcastDeliveryJob stub
    allow(BroadcastDeliveryJob).to receive(:perform_later)

    # LimitService가 사용하는 broadcast_repository 메서드 stub
    allow(broadcast_repository).to receive(:count_hourly_by_user).and_return(0)
    allow(broadcast_repository).to receive(:last_broadcast_time).and_return(nil)

    # broadcast_limits 설정이 존재하도록 보장
    unless SystemSetting.exists?(setting_key: "broadcast_limits")
      SystemSetting.create!(
        setting_key: "broadcast_limits",
        setting_value: { "daily_limit" => 20, "hourly_limit" => 5, "cooldown_minutes" => 10, "bypass_roles" => ["admin"] },
        description: "Test broadcast limits"
      )
    end
  end

  # 공통 헬퍼: broadcast mock 설정
  def setup_broadcast_mock(broadcast)
    # Active Storage audio 모킹
    audio_double = instance_double(ActiveStorage::Attached::One)
    allow(broadcast).to receive(:audio).and_return(audio_double)
    allow(audio_double).to receive(:attach)
    allow(audio_double).to receive(:attached?).and_return(false)
  end

  describe '#execute' do
    context '성공적인 브로드캐스트 생성' do
      let(:broadcast) { create(:broadcast, user: user) }
      let(:selected_recipients) { recipients.take(2) }

      before do
        # 오디오 파일 mock
        allow(audio_file).to receive(:present?).and_return(true)
        allow(audio_file).to receive(:size).and_return(1.megabyte)
        allow(audio_file).to receive(:content_type).and_return('audio/wav')

        # Mock 설정
        allow(user).to receive(:status_active?).and_return(true)
        allow(user).to receive(:premium?).and_return(false)
        allow(broadcast_repository).to receive(:count_today_by_user).and_return(0)
        allow(recipient_selector).to receive(:select).and_return(selected_recipients)

        # 트랜잭션 내 동작
        allow(broadcast_repository).to receive(:create!).and_return(broadcast)
        setup_broadcast_mock(broadcast)

        # 이벤트 발행
        allow(event_publisher).to receive(:publish)
      end

      it '성공 응답을 반환한다' do
        result = command.execute

        expect(result[:success]).to be true
        expect(result[:broadcast]).to be_present
        expect(result[:recipient_count]).to eq(2)
      end

      it '브로드캐스트를 생성한다' do
        expect(broadcast_repository).to receive(:create!).with(
          hash_including(
            user: user,
            content: "테스트 브로드캐스트",
            active: true
          )
        )

        command.execute
      end

      it '오디오 파일을 첨부한다' do
        expect(broadcast).to receive_message_chain(:audio, :attach).with(audio_file)
        command.execute
      end

      it '지갑에서 금액을 차감한다' do
        expect(wallet).to receive(:withdraw).with(100, description: "브로드캐스트 전송")

        command.execute
      end

      it 'BroadcastDeliveryJob를 호출한다' do
        expect(BroadcastDeliveryJob).to receive(:perform_later).with(
          broadcast.id,
          selected_recipients.map(&:id),
          nil
        )

        command.execute
      end

      it '이벤트를 발행한다' do
        expect(event_publisher).to receive(:publish).with(
          an_instance_of(BroadcastCreatedEvent)
        )

        command.execute
      end
    end

    context '검증 실패' do
      before do
        allow(user).to receive(:status_active?).and_return(true)
        allow(user).to receive(:premium?).and_return(false)
        allow(broadcast_repository).to receive(:count_today_by_user).and_return(0)
      end

      context '오디오 파일이 없는 경우' do
        subject(:command) do
          described_class.new(
            user: user,
            audio_file: nil,
            content: "테스트",
            recipient_count: 5,
            broadcast_repository: broadcast_repository,
            recipient_selector: recipient_selector,
            event_publisher: event_publisher
          )
        end

        it '음성 파일 오류를 반환한다' do
          result = command.execute

          expect(result[:success]).to be false
          expect(result[:error]).to include('음성 파일이 필요합니다')
          expect(result[:status]).to eq(:bad_request)
        end
      end

      context '파일 크기가 너무 큰 경우' do
        let(:large_file) { instance_double(ActionDispatch::Http::UploadedFile) }

        subject(:command) do
          described_class.new(
            user: user,
            audio_file: large_file,
            content: "테스트",
            recipient_count: 5,
            broadcast_repository: broadcast_repository,
            recipient_selector: recipient_selector,
            event_publisher: event_publisher
          )
        end

        before do
          allow(large_file).to receive(:present?).and_return(true)
          allow(large_file).to receive(:size).and_return(15.megabytes)
        end

        it '파일 크기 오류를 반환한다' do
          result = command.execute

          expect(result[:success]).to be false
          expect(result[:error]).to include('음성 파일이 너무 큽니다')
          expect(result[:status]).to eq(:bad_request)
        end
      end

      context '지원하지 않는 파일 형식인 경우' do
        let(:invalid_file) { instance_double(ActionDispatch::Http::UploadedFile) }

        subject(:command) do
          described_class.new(
            user: user,
            audio_file: invalid_file,
            content: "테스트",
            recipient_count: 5,
            broadcast_repository: broadcast_repository,
            recipient_selector: recipient_selector,
            event_publisher: event_publisher
          )
        end

        before do
          allow(invalid_file).to receive(:present?).and_return(true)
          allow(invalid_file).to receive(:size).and_return(1.megabyte)
          allow(invalid_file).to receive(:content_type).and_return('text/plain')
        end

        it '파일 형식 오류를 반환한다' do
          result = command.execute

          expect(result[:success]).to be false
          expect(result[:error]).to include('지원하지 않는 파일 형식입니다')
          expect(result[:status]).to eq(:bad_request)
        end
      end
    end

    context '자격 검증' do
      before do
        allow(audio_file).to receive(:present?).and_return(true)
        allow(audio_file).to receive(:size).and_return(1.megabyte)
        allow(audio_file).to receive(:content_type).and_return('audio/wav')
      end

      context '비활성 계정인 경우' do
        before do
          allow(user).to receive(:status_active?).and_return(false)
        end

        it '계정 상태 오류를 반환한다' do
          result = command.execute

          expect(result[:success]).to be false
          expect(result[:error]).to include('현재 계정 상태로는 브로드캐스트를 보낼 수 없습니다')
          expect(result[:status]).to eq(:forbidden)
        end
      end

      context '일일 한도를 초과한 경우' do
        before do
          allow(user).to receive(:status_active?).and_return(true)
          allow(user).to receive(:premium?).and_return(false)
          # 일일 제한 기본값은 20 (system_settings에서)
          allow(broadcast_repository).to receive(:count_today_by_user).and_return(20)
        end

        it '일일 한도 오류를 반환한다' do
          result = command.execute

          expect(result[:success]).to be false
          expect(result[:error]).to include('일일 브로드캐스트 한도를 초과했습니다')
          expect(result[:status]).to eq(:too_many_requests)
        end
      end

      context '프리미엄 사용자의 일일 한도' do
        before do
          allow(user).to receive(:status_active?).and_return(true)
          allow(user).to receive(:premium?).and_return(true)
          allow(broadcast_repository).to receive(:count_today_by_user).and_return(15) # 일반은 10, 프리미엄은 20
        end

        it '프리미엄 한도 내에서는 통과한다' do
          broadcast = create(:broadcast, user: user)
          allow(recipient_selector).to receive(:select).and_return(recipients.take(2))
          allow(broadcast_repository).to receive(:create!).and_return(broadcast)
          setup_broadcast_mock(broadcast)
          allow(event_publisher).to receive(:publish)

          result = command.execute

          expect(result[:success]).to be true
        end
      end

      context '잔액이 부족한 경우' do
        before do
          allow(user).to receive(:status_active?).and_return(true)
          allow(user).to receive(:premium?).and_return(false)
          allow(broadcast_repository).to receive(:count_today_by_user).and_return(0)
          # 잔액이 50인 wallet mock
          low_balance_wallet = instance_double(Wallet, balance: 50)
          allow(user).to receive(:wallet).and_return(low_balance_wallet)
        end

        it '잔액 부족 오류를 반환한다' do
          result = command.execute

          expect(result[:success]).to be false
          expect(result[:error]).to include('포인트가 부족합니다')
          expect(result[:status]).to eq(:payment_required)
          expect(result[:balance_needed]).to eq(100)
          expect(result[:current_balance]).to eq(50)
        end
      end
    end

    context '수신자 수 정규화' do
      before do
        allow(user).to receive(:status_active?).and_return(true)
        allow(user).to receive(:premium?).and_return(false)
        allow(broadcast_repository).to receive(:count_today_by_user).and_return(0)
      end

      context '수신자 수가 0 이하인 경우' do
        subject(:command) do
          described_class.new(
            user: user,
            audio_file: audio_file,
            content: "테스트",
            recipient_count: 0,
            broadcast_repository: broadcast_repository,
            recipient_selector: recipient_selector,
            event_publisher: event_publisher
          )
        end

        it '기본값 5로 설정된다' do
          broadcast = create(:broadcast, user: user)
          allow(recipient_selector).to receive(:select).with(
            sender: user,
            count: 5,
            exclude_blocked: true,
            target_gender: nil
          ).and_return(recipients)
          allow(broadcast_repository).to receive(:create!).and_return(broadcast)
          setup_broadcast_mock(broadcast)
          allow(event_publisher).to receive(:publish)

          command.execute

          expect(recipient_selector).to have_received(:select).with(
            sender: user,
            count: 5,
            exclude_blocked: true,
            target_gender: nil
          )
        end
      end

      context '수신자 수가 10 초과인 경우' do
        subject(:command) do
          described_class.new(
            user: user,
            audio_file: audio_file,
            content: "테스트",
            recipient_count: 15,
            broadcast_repository: broadcast_repository,
            recipient_selector: recipient_selector,
            event_publisher: event_publisher
          )
        end

        it '최대값 10으로 설정된다' do
          broadcast = create(:broadcast, user: user)
          allow(recipient_selector).to receive(:select).with(
            sender: user,
            count: 10,
            exclude_blocked: true,
            target_gender: nil
          ).and_return(recipients)
          allow(broadcast_repository).to receive(:create!).and_return(broadcast)
          setup_broadcast_mock(broadcast)
          allow(event_publisher).to receive(:publish)

          command.execute

          expect(recipient_selector).to have_received(:select).with(
            sender: user,
            count: 10,
            exclude_blocked: true,
            target_gender: nil
          )
        end
      end
    end

    context '트랜잭션 롤백' do
      before do
        allow(user).to receive(:status_active?).and_return(true)
        allow(user).to receive(:premium?).and_return(false)
        allow(broadcast_repository).to receive(:count_today_by_user).and_return(0)
        allow(recipient_selector).to receive(:select).and_return(recipients.take(2))

        # 브로드캐스트 생성 중 에러 발생
        allow(broadcast_repository).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it '트랜잭션이 롤백되고 에러를 반환한다' do
        result = command.execute

        expect(result[:success]).to be false
        expect(result[:error]).to eq("브로드캐스트 생성 중 오류가 발생했습니다.")
        expect(result[:status]).to eq(:internal_server_error)
      end
    end

    context '기본 content 값' do
      subject(:command) do
        described_class.new(
          user: user,
          audio_file: audio_file,
          content: nil,
          recipient_count: 5,
          broadcast_repository: broadcast_repository,
          recipient_selector: recipient_selector,
          event_publisher: event_publisher
        )
      end

      it 'content가 nil이면 기본 메시지를 사용한다' do
        broadcast = create(:broadcast, user: user)
        allow(user).to receive(:status_active?).and_return(true)
        allow(user).to receive(:premium?).and_return(false)
        allow(broadcast_repository).to receive(:count_today_by_user).and_return(0)
        allow(recipient_selector).to receive(:select).and_return(recipients.take(2))
        allow(broadcast_repository).to receive(:create!).and_return(broadcast)
        setup_broadcast_mock(broadcast)
        allow(event_publisher).to receive(:publish)

        expect(broadcast_repository).to receive(:create!).with(
          hash_including(content: "새로운 음성 메시지")
        )

        command.execute
      end
    end
  end
end
