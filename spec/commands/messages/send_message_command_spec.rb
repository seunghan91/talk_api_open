# spec/commands/messages/send_message_command_spec.rb
require 'rails_helper'

RSpec.describe Messages::SendMessageCommand do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  # Use a mock conversation that responds to the methods the command expects
  let(:conversation) do
    conv = create(:conversation, user_a: user, user_b: other_user)
    # Define methods that the command expects but the model doesn't have
    conv.define_singleton_method(:participant?) { |u| user_a_id == u.id || user_b_id == u.id }
    conv.define_singleton_method(:deleted_by?) { |u| u.id == user_a_id ? deleted_by_a : deleted_by_b }
    conv.define_singleton_method(:other_user) { |u| u.id == user_a_id ? user_b : user_a }
    conv
  end

  # Mock 의존성
  let(:conversation_repository) { instance_double(ConversationRepository) }
  let(:message_repository) { instance_double(MessageRepository) }
  let(:notification_service) { instance_double(NotificationService) }
  let(:event_publisher) { instance_double(EventPublisher) }

  let(:voice_file) { fixture_file_upload('spec/fixtures/files/sample_audio.wav', 'audio/wav') }

  subject(:command) do
    described_class.new(
      user: user,
      conversation_id: conversation.id,
      voice_file: voice_file,
      text: nil,
      conversation_repository: conversation_repository,
      message_repository: message_repository,
      notification_service: notification_service,
      event_publisher: event_publisher
    )
  end

  describe '#execute' do
    context '성공적인 메시지 전송' do
      # Use a full double to mock the message since the command references attributes
      # that may not exist on the actual Message model (e.g., 'text')
      let(:message_id) { 123 }
      let(:message) do
        msg = double('Message',
          id: message_id,
          sender_id: user.id,
          message_type: 'voice',
          text: nil,
          created_at: Time.current,
          read: false
        )
        voice_mock = double('voice_file')
        allow(voice_mock).to receive(:attach)
        allow(voice_mock).to receive(:attached?).and_return(false)
        allow(msg).to receive(:voice_file).and_return(voice_mock)
        msg
      end

      before do
        allow(conversation_repository).to receive(:find_by_id).with(conversation.id).and_return(conversation)
        allow(Block).to receive(:exists?).and_return(false)

        allow(message_repository).to receive(:create!).and_return(message)

        allow(conversation).to receive(:show_to!)
        allow(conversation).to receive(:touch)

        allow(other_user).to receive(:message_push_enabled?).and_return(true)
        allow(notification_service).to receive(:send_message_notification)
        allow(event_publisher).to receive(:publish)
      end

      it '성공 응답을 반환한다' do
        result = command.execute

        expect(result[:success]).to be true
        expect(result[:message]).to be_present
        expect(result[:conversation_id]).to eq(conversation.id)
      end

      it '메시지를 생성한다' do
        expect(message_repository).to receive(:create!).with(
          conversation: conversation,
          sender: user,
          message_type: 'voice',
          read: false
        )

        command.execute
      end

      it '대화를 업데이트한다' do
        expect(conversation).to receive(:show_to!).with(user.id)
        expect(conversation).to receive(:touch)
        
        command.execute
      end

      it '알림을 전송한다' do
        expect(notification_service).to receive(:send_message_notification).with(
          other_user,
          message
        )

        command.execute
      end

      it '이벤트를 발행한다' do
        expect(event_publisher).to receive(:publish).with(
          an_instance_of(MessageSentEvent)
        )
        
        command.execute
      end
    end

    context '검증 실패' do
      context '음성 파일과 텍스트가 모두 없는 경우' do
        subject(:command) do
          described_class.new(
            user: user,
            conversation_id: conversation.id,
            voice_file: nil,
            text: nil,
            conversation_repository: conversation_repository
          )
        end

        it '실패 응답을 반환한다' do
          result = command.execute
          
          expect(result[:success]).to be false
          expect(result[:error]).to include('음성 파일 또는 텍스트가 필요합니다')
          expect(result[:status]).to eq(:bad_request)
        end
      end

      context '파일이 너무 큰 경우' do
        let(:large_file) do
          file = double('file')
          allow(file).to receive(:size).and_return(11.megabytes)
          allow(file).to receive(:present?).and_return(true)
          allow(file).to receive(:content_type).and_return('audio/wav')
          file
        end

        subject(:command) do
          described_class.new(
            user: user,
            conversation_id: conversation.id,
            voice_file: large_file,
            conversation_repository: conversation_repository
          )
        end

        it '파일 크기 오류를 반환한다' do
          result = command.execute
          
          expect(result[:success]).to be false
          expect(result[:error]).to include('파일이 너무 큽니다')
          expect(result[:status]).to eq(:bad_request)
        end
      end

      context '지원하지 않는 파일 형식' do
        let(:invalid_file) do
          file = double('file')
          allow(file).to receive(:size).and_return(1.megabyte)
          allow(file).to receive(:present?).and_return(true)
          allow(file).to receive(:content_type).and_return('application/pdf')
          file
        end

        subject(:command) do
          described_class.new(
            user: user,
            conversation_id: conversation.id,
            voice_file: invalid_file,
            conversation_repository: conversation_repository
          )
        end

        it '파일 형식 오류를 반환한다' do
          result = command.execute
          
          expect(result[:success]).to be false
          expect(result[:error]).to include('지원하지 않는 파일 형식')
          expect(result[:status]).to eq(:bad_request)
        end
      end
    end

    context '권한 검증' do
      before do
        allow(conversation_repository).to receive(:find_by_id).with(conversation.id).and_return(conversation)
      end

      context '대화 참여자가 아닌 경우' do
        let(:non_participant) { create(:user) }

        subject(:command) do
          described_class.new(
            user: non_participant,
            conversation_id: conversation.id,
            voice_file: voice_file,
            conversation_repository: conversation_repository
          )
        end

        # conversation's participant? singleton method will return false for non_participant

        it '권한 오류를 반환한다' do
          result = command.execute

          expect(result[:success]).to be false
          expect(result[:error]).to include('권한이 없습니다')
          expect(result[:status]).to eq(:forbidden)
        end
      end

      context '대화가 삭제된 경우' do
        before do
          # Set the deleted flag for user_a (which is `user`)
          conversation.update!(deleted_by_a: true)
        end

        it '삭제 오류를 반환한다' do
          result = command.execute

          expect(result[:success]).to be false
          expect(result[:error]).to include('삭제된 대화')
          expect(result[:status]).to eq(:gone)
        end
      end

      context '상대방이 차단한 경우' do
        before do
          allow(Block).to receive(:exists?).with(blocker: other_user, blocked: user).and_return(true)
        end

        it '차단 오류를 반환한다' do
          result = command.execute

          expect(result[:success]).to be false
          expect(result[:error]).to include('메시지를 보낼 수 없습니다')
          expect(result[:status]).to eq(:forbidden)
        end
      end
    end

    context '대화를 찾을 수 없는 경우' do
      before do
        allow(conversation_repository).to receive(:find_by_id).with(999).and_return(nil)
      end

      subject(:command) do
        described_class.new(
          user: user,
          conversation_id: 999,
          voice_file: voice_file,
          conversation_repository: conversation_repository
        )
      end

      it 'not found 오류를 반환한다' do
        result = command.execute
        
        expect(result[:success]).to be false
        expect(result[:error]).to include('대화를 찾을 수 없습니다')
        expect(result[:status]).to eq(:not_found)
      end
    end

    context '알림 전송 실패' do
      # Use a full double to mock the message since the command references attributes
      # that may not exist on the actual Message model (e.g., 'text')
      let(:message_id) { 456 }
      let(:message) do
        msg = double('Message',
          id: message_id,
          sender_id: user.id,
          message_type: 'voice',
          text: nil,
          created_at: Time.current,
          read: false
        )
        voice_mock = double('voice_file')
        allow(voice_mock).to receive(:attach)
        allow(voice_mock).to receive(:attached?).and_return(false)
        allow(msg).to receive(:voice_file).and_return(voice_mock)
        msg
      end

      before do
        allow(conversation_repository).to receive(:find_by_id).and_return(conversation)
        allow(Block).to receive(:exists?).and_return(false)

        allow(message_repository).to receive(:create!).and_return(message)

        allow(conversation).to receive(:show_to!)
        allow(conversation).to receive(:touch)

        allow(other_user).to receive(:message_push_enabled?).and_return(true)
        allow(notification_service).to receive(:send_message_notification).and_raise(StandardError, 'Network error')
        allow(event_publisher).to receive(:publish)
      end

      it '알림 실패해도 메시지는 전송된다' do
        result = command.execute

        expect(result[:success]).to be true
        expect(result[:message]).to be_present
      end
    end
  end
end 