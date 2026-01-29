require 'rails_helper'

RSpec.describe MessageService do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:conversation) { create(:conversation, user_a: user, user_b: other_user) }
  let(:service) { described_class.new(user) }

  describe '#send_message' do
    let(:voice_file) { fixture_file_upload('spec/fixtures/files/sample_audio.wav', 'audio/wav') }

    context 'when sending a voice message' do
      let(:params) do
        {
          message_type: 'voice',
          voice_file: voice_file
        }
      end

      it 'creates a voice message successfully' do
        expect {
          result = service.send_message(conversation.id, params)
          expect(result.success?).to be true
        }.to change(Message, :count).by(1)

        message = Message.last
        expect(message.message_type).to eq('voice')
        expect(message.voice_file).to be_attached
      end

      it 'returns formatted message data' do
        result = service.send_message(conversation.id, params)

        expect(result.message).to include(
          :id,
          :conversation_id,
          :sender,
          :message_type,
          :voice_url,
          :created_at
        )
        expect(result.message[:sender][:id]).to eq(user.id)
      end

      it 'invalidates caches' do
        expect(Rails.cache).to receive(:delete).with("conversation-messages-#{conversation.id}")
        expect(Rails.cache).to receive(:delete).with("conversations-user-#{user.id}")
        expect(Rails.cache).to receive(:delete).with("conversations-user-#{other_user.id}")

        service.send_message(conversation.id, params)
      end
    end

    context 'when user is not a participant' do
      let(:other_conversation) { create(:conversation) }

      it 'returns an error' do
        result = service.send_message(other_conversation.id, message_type: 'voice', voice_file: voice_file)

        expect(result.success?).to be false
        expect(result.error).to eq("권한이 없습니다.")
      end
    end

    context 'when conversation is soft deleted' do
      before do
        conversation.update(deleted_by_a: true)
      end

      it 'restores visibility when sending message' do
        result = service.send_message(conversation.id, message_type: 'voice', voice_file: voice_file)

        expect(result.success?).to be true
        conversation.reload
        expect(conversation.deleted_by_a).to be false
      end
    end

    context 'with invalid file types' do
      it 'rejects invalid audio files' do
        invalid_audio = fixture_file_upload('spec/fixtures/files/sample.txt', 'text/plain')
        params = { message_type: 'voice', voice_file: invalid_audio }

        result = service.send_message(conversation.id, params)

        expect(result.success?).to be false
        expect(result.error).to include('오디오 파일')
      end
    end
  end

  describe '#reply_to_broadcast' do
    let(:broadcast) { create(:broadcast, user: other_user) }
    let(:voice_file) { fixture_file_upload('spec/fixtures/files/sample_audio.wav', 'audio/wav') }

    before do
      create(:broadcast_recipient, broadcast: broadcast, user: user)
    end

    context 'when user is a broadcast recipient' do
      let(:params) do
        {
          message_type: 'voice',
          voice_file: voice_file
        }
      end

      it 'creates a conversation and sends reply' do
        # Note: When creating a new conversation from a broadcast, the Conversation model
        # also creates an initial broadcast message. So we expect 2 messages total:
        # 1 from Conversation.find_or_create_conversation (broadcast type)
        # 1 from the actual reply (broadcast_reply type)
        expect {
          result = service.reply_to_broadcast(broadcast.id, params)
          expect(result.success?).to be true
        }.to change(Conversation, :count).by(1)
                                          .and change(Message, :count).by(2)
      end

      it 'includes conversation_id in response' do
        result = service.reply_to_broadcast(broadcast.id, params)

        expect(result.success?).to be true
        expect(result.message[:conversation_id]).to be_present
      end

      it 'links message to broadcast' do
        result = service.reply_to_broadcast(broadcast.id, params)

        message = Message.last
        expect(message.broadcast_id).to eq(broadcast.id)
      end
    end

    context 'when user is not a broadcast recipient' do
      let(:non_recipient) { create(:user) }
      let(:non_recipient_service) { described_class.new(non_recipient) }

      it 'returns an error' do
        result = non_recipient_service.reply_to_broadcast(broadcast.id, voice_file: voice_file)

        expect(result.success?).to be false
        expect(result.error).to eq("권한이 없습니다.")
      end
    end

    context 'when broadcast does not exist' do
      it 'returns an error' do
        result = service.reply_to_broadcast(999999, voice_file: voice_file)

        expect(result.success?).to be false
        expect(result.error).to eq("브로드캐스트를 찾을 수 없습니다.")
      end
    end
  end

  describe '#list_messages' do
    let!(:messages) { create_list(:message, 5, conversation: conversation, sender: other_user) }

    context 'with pagination' do
      it 'returns paginated messages' do
        result = service.list_messages(conversation.id, page: 1, per_page: 2)

        expect(result.success?).to be true
        expect(result.message.size).to eq(2)
      end

      it 'orders messages by created_at desc' do
        result = service.list_messages(conversation.id)

        expect(result.message.first[:id]).to eq(messages.last.id)
        expect(result.message.last[:id]).to eq(messages.first.id)
      end
    end

    context 'with unread messages' do
      before do
        messages.each { |m| m.update(read: false) }
      end

      it 'marks messages as read' do
        result = service.list_messages(conversation.id)

        expect(result.success?).to be true
        messages.each do |message|
          expect(message.reload.read).to be true
        end
      end

      it 'only marks other users messages as read' do
        own_message = create(:message, conversation: conversation, sender: user, read: false)

        service.list_messages(conversation.id)

        expect(own_message.reload.read).to be false
      end
    end

    context 'when user is not a participant' do
      let(:other_conversation) { create(:conversation) }

      it 'returns an error' do
        result = service.list_messages(other_conversation.id)

        expect(result.success?).to be false
        expect(result.error).to eq("권한이 없습니다.")
      end
    end
  end

  describe '#delete_message' do
    let(:message) { create(:message, conversation: conversation, sender: user) }

    context 'when user is the sender' do
      it 'soft deletes the message' do
        result = service.delete_message(message.id)

        expect(result.success?).to be true
        message.reload
        expect(message.deleted_by_a).to be true
      end

      it 'returns success message' do
        result = service.delete_message(message.id)

        expect(result.message).to eq("메시지가 삭제되었습니다.")
      end
    end

    context 'when user is not the sender' do
      let(:other_message) { create(:message, conversation: conversation, sender: other_user) }

      it 'returns an error' do
        result = service.delete_message(other_message.id)

        expect(result.success?).to be false
        expect(result.error).to eq("권한이 없습니다.")
      end
    end

    context 'when message does not exist' do
      it 'returns an error' do
        result = service.delete_message(999999)

        expect(result.success?).to be false
        expect(result.error).to eq("메시지를 찾을 수 없습니다.")
      end
    end
  end

  describe '#mark_as_read' do
    let(:conversation2) { create(:conversation, user_a: user, user_b: create(:user)) }
    let!(:unread_messages) do
      [
        create(:message, conversation: conversation, sender: other_user, read: false),
        create(:message, conversation: conversation, sender: other_user, read: false),
        create(:message, conversation: conversation2, sender: conversation2.user_b, read: false)
      ]
    end

    it 'marks specified messages as read' do
      message_ids = unread_messages[0..1].map(&:id)

      result = service.mark_as_read(message_ids)

      expect(result.success?).to be true
      expect(result.message).to eq("2개 메시지를 읽음 처리했습니다.")
      
      expect(unread_messages[0].reload.read).to be true
      expect(unread_messages[1].reload.read).to be true
      expect(unread_messages[2].reload.read).to be false
    end

    it 'only marks messages in conversations user participates in' do
      other_conversation = create(:conversation)
      other_message = create(:message, conversation: other_conversation, read: false)

      result = service.mark_as_read([other_message.id])

      expect(result.success?).to be true
      expect(result.message).to eq("0개 메시지를 읽음 처리했습니다.")
      expect(other_message.reload.read).to be false
    end

    it 'does not mark own messages as read' do
      own_message = create(:message, conversation: conversation, sender: user, read: false)

      result = service.mark_as_read([own_message.id])

      expect(result.success?).to be true
      expect(result.message).to eq("0개 메시지를 읽음 처리했습니다.")
      expect(own_message.reload.read).to be false
    end
  end
end