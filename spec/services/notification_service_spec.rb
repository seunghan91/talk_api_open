require 'rails_helper'

RSpec.describe NotificationService do
  let(:user) { create(:user, push_token: 'fcm-device-token-xxxxx', push_enabled: true) }
  let(:service) { described_class.new }

  describe '#send_notification' do
    context '푸시 알림이 활성화된 경우' do
      it '푸시 알림을 전송한다' do
        expect_any_instance_of(NotificationService::FcmPushClient).to receive(:send_messages)

        result = service.send_notification(
          user: user,
          type: :message,
          title: '새 메시지',
          body: '안녕하세요!'
        )

        expect(result.success?).to be true
      end

      it '알림 기록을 생성한다' do
        expect {
          service.send_notification(
            user: user,
            type: :message,
            title: '새 메시지',
            body: '안녕하세요!'
          )
        }.to change(Notification, :count).by(1)
      end
    end

    context '푸시 알림이 비활성화된 경우' do
      before { user.update(push_enabled: false) }

      it '푸시 알림을 전송하지 않는다' do
        expect_any_instance_of(NotificationService::FcmPushClient).not_to receive(:send_messages)

        result = service.send_notification(
          user: user,
          type: :message,
          title: '새 메시지',
          body: '안녕하세요!'
        )

        expect(result.success?).to be true
      end

      it '알림 기록은 생성한다' do
        expect {
          service.send_notification(
            user: user,
            type: :message,
            title: '새 메시지',
            body: '안녕하세요!'
          )
        }.to change(Notification, :count).by(1)
      end
    end

    context '푸시 토큰이 없는 경우' do
      before { user.update(push_token: nil) }

      it '푸시 알림을 전송하지 않는다' do
        expect_any_instance_of(NotificationService::FcmPushClient).not_to receive(:send_messages)

        result = service.send_notification(
          user: user,
          type: :message,
          title: '새 메시지',
          body: '안녕하세요!'
        )

        expect(result.success?).to be true
      end
    end
  end

  describe '#send_broadcast_notification' do
    let(:broadcast) { create(:broadcast) }

    context '브로드캐스트 알림이 활성화된 경우' do
      before { user.update(broadcast_push_enabled: true) }

      it '브로드캐스트 알림을 전송한다' do
        expect_any_instance_of(NotificationService::FcmPushClient).to receive(:send_messages)

        result = service.send_broadcast_notification(user, broadcast)
        expect(result.success?).to be true
      end

      it '올바른 제목과 내용을 포함한다' do
        allow_any_instance_of(NotificationService::FcmPushClient).to receive(:send_messages) do |_, messages|
          message = messages.first
          expect(message[:to]).to eq(user.push_token)
          expect(message[:title]).to include(broadcast.user.nickname)
          # broadcast.content가 있으면 그 내용을, 없으면 기본 메시지를 사용
          expect(message[:body]).to eq(broadcast.content.presence || "새로운 음성 메시지가 도착했습니다")
        end

        service.send_broadcast_notification(user, broadcast)
      end
    end

    context '브로드캐스트 알림이 비활성화된 경우' do
      before { user.update(broadcast_push_enabled: false) }

      it '알림을 전송하지 않는다' do
        expect_any_instance_of(NotificationService::FcmPushClient).not_to receive(:send_messages)

        result = service.send_broadcast_notification(user, broadcast)
        expect(result.success?).to be true
      end
    end
  end

  describe '#send_message_notification' do
    let(:message) { create(:message) }

    context '메시지 알림이 활성화된 경우' do
      before { user.update(message_push_enabled: true) }

      it '메시지 알림을 전송한다' do
        expect_any_instance_of(NotificationService::FcmPushClient).to receive(:send_messages)

        result = service.send_message_notification(user, message)
        expect(result.success?).to be true
      end
    end

    context '메시지 알림이 비활성화된 경우' do
      before { user.update(message_push_enabled: false) }

      it '알림을 전송하지 않는다' do
        expect_any_instance_of(NotificationService::FcmPushClient).not_to receive(:send_messages)

        result = service.send_message_notification(user, message)
        expect(result.success?).to be true
      end
    end
  end

  describe '#send_bulk_notifications' do
    let(:users) { create_list(:user, 3, push_token: 'fcm-device-token-xxxxx', push_enabled: true) }

    it '여러 사용자에게 동시에 알림을 전송한다' do
      expect_any_instance_of(NotificationService::FcmPushClient).to receive(:send_messages).once

      result = service.send_bulk_notifications(
        users: users,
        type: :system,
        title: '공지사항',
        body: '중요한 공지사항입니다.'
      )

      expect(result.success?).to be true
      expect(result.sent_count).to eq(3)
    end

    it '각 사용자에게 알림 기록을 생성한다' do
      expect {
        service.send_bulk_notifications(
          users: users,
          type: :system,
          title: '공지사항',
          body: '중요한 공지사항입니다.'
        )
      }.to change(Notification, :count).by(3)
    end
  end

  describe '의존성 주입' do
    it '커스텀 푸시 클라이언트를 주입받을 수 있다' do
      mock_client = double('PushClient')
      service_with_injection = described_class.new(push_client: mock_client)

      expect(mock_client).to receive(:send_messages).and_return(true)

      service_with_injection.send_notification(
        user: user,
        type: :system,
        title: 'Test',
        body: 'Test message'
      )
    end
  end

  describe 'Strategy 패턴' do
    it '알림 타입에 따라 다른 전략을 사용한다' do
      # 브로드캐스트 전략
      broadcast_strategy = NotificationService::BroadcastStrategy.new
      expect(broadcast_strategy.format_title(create(:broadcast))).to include('새로운 브로드캐스트')

      # 메시지 전략
      message_strategy = NotificationService::MessageStrategy.new
      expect(message_strategy.format_title(create(:message))).to include('새 메시지')

      # 공지사항 전략
      announcement_strategy = NotificationService::AnnouncementStrategy.new
      expect(announcement_strategy.format_title(nil)).to include('공지사항')
    end
  end
end
