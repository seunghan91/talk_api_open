require 'rails_helper'

RSpec.describe Broadcasts::CreateService do
  let(:user) { create(:user) }
  let(:audio_file) { fixture_file_upload('spec/fixtures/files/sample_audio.wav', 'audio/wav') }
  let(:content) { "테스트 브로드캐스트 메시지" }
  let(:recipient_count) { 5 }

  subject(:service) do
    described_class.new(
      user: user,
      audio: audio_file,
      content: content,
      recipient_count: recipient_count
    )
  end

  describe '#call' do
    context '유효한 파라미터로 호출할 때' do
      it '브로드캐스트를 생성한다' do
        expect {
          result = service.call
          expect(result.success?).to be true
          expect(result.broadcast).to be_persisted
          expect(result.broadcast.user).to eq(user)
          expect(result.broadcast.content).to eq(content)
        }.to change(Broadcast, :count).by(1)
      end

      it '브로드캐스트 워커를 호출한다' do
        expect(BroadcastWorker).to receive(:perform_async).once
        service.call
      end

      it '성공 Result 객체를 반환한다' do
        result = service.call
        expect(result).to be_a(Broadcasts::CreateService::Result)
        expect(result.success?).to be true
        expect(result.error).to be_nil
      end
    end

    context '음성 파일이 없을 때' do
      let(:audio_file) { nil }

      it '브로드캐스트를 생성하지 않는다' do
        expect {
          service.call
        }.not_to change(Broadcast, :count)
      end

      it '실패 Result 객체를 반환한다' do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("음성 파일이 필요합니다")
      end
    end

    context '텍스트가 너무 길 때' do
      let(:content) { "a" * 201 } # 200자 제한 초과

      it '실패 Result 객체를 반환한다' do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("텍스트가 너무 깁니다")
      end
    end

    context '수신자 수가 유효하지 않을 때' do
      context '0 이하일 때' do
        let(:recipient_count) { 0 }

        it '기본값 5를 사용한다' do
          expect(BroadcastWorker).to receive(:perform_async).with(anything, 5)
          service.call
        end
      end

      context '10 초과일 때' do
        let(:recipient_count) { 15 }

        it '최대값 10을 사용한다' do
          expect(BroadcastWorker).to receive(:perform_async).with(anything, 10)
          service.call
        end
      end
    end

    context '예외가 발생할 때' do
      before do
        allow_any_instance_of(Broadcast).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
      end

      it '실패 Result 객체를 반환한다' do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).not_to be_nil
      end

      it '브로드캐스트를 생성하지 않는다' do
        expect {
          service.call
        }.not_to change(Broadcast, :count)
      end
    end
  end

  describe '의존성 주입' do
    it '외부 서비스를 주입받을 수 있다' do
      mock_worker = double('Worker')
      service_with_injection = described_class.new(
        user: user,
        audio: audio_file,
        content: content,
        recipient_count: recipient_count,
        worker: mock_worker
      )

      expect(mock_worker).to receive(:perform_async)
      allow_any_instance_of(Broadcast).to receive(:save!).and_return(true)

      service_with_injection.call
    end
  end
end
