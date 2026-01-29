require 'rails_helper'

RSpec.describe ConversationService do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:service) { described_class.new(user) }
  let(:conversation) { create(:conversation, user_a: user, user_b: other_user) }

  describe '#list_conversations' do
    let!(:conversation1) { create(:conversation, user_a: user, user_b: other_user) }
    let!(:conversation2) { create(:conversation, user_a: create(:user), user_b: user) }
    let!(:deleted_conversation) { create(:conversation, user_a: user, user_b: create(:user), deleted_by_a: true) }
    let!(:other_conversation) { create(:conversation, user_a: create(:user), user_b: create(:user)) }

    before do
      # Add messages to conversations
      create(:message, conversation: conversation1, sender: other_user)
      create(:message, conversation: conversation2, sender: conversation2.user_a)
    end

    it 'returns only visible conversations for the user' do
      result = service.list_conversations

      expect(result.success?).to be true
      expect(result.conversation.size).to eq(2)
      expect(result.conversation.map { |c| c[:id] }).to contain_exactly(conversation1.id, conversation2.id)
    end

    it 'formats conversations correctly' do
      result = service.list_conversations
      conv = result.conversation.first

      expect(conv).to have_key(:id)
      expect(conv).to have_key(:with_user)
      expect(conv).to have_key(:last_message)
      expect(conv).to have_key(:favorite)
      expect(conv).to have_key(:unread_count)
    end

    it 'handles errors gracefully' do
      allow(Conversation).to receive(:for_user).and_raise(StandardError, "Database error")

      result = service.list_conversations

      expect(result.success?).to be false
      expect(result.error).to eq("대화 목록을 불러오는 데 실패했습니다.")
    end
  end

  describe '#show_conversation' do
    context 'when user is a participant' do
      before do
        create_list(:message, 3, conversation: conversation)
      end

      it 'returns the conversation and messages' do
        result = service.show_conversation(conversation.id)

        expect(result.success?).to be true
        expect(result.conversation).to eq(conversation)
        expect(result.message.size).to eq(3)
      end

      it 'restores visibility if conversation was hidden' do
        conversation.update(deleted_by_a: true)

        result = service.show_conversation(conversation.id)

        expect(result.success?).to be true
        conversation.reload
        expect(conversation.deleted_by_a).to be false
      end
    end

    context 'when user is not a participant' do
      let(:other_conversation) { create(:conversation) }

      it 'returns an error' do
        result = service.show_conversation(other_conversation.id)

        expect(result.success?).to be false
        expect(result.error).to eq("권한이 없습니다.")
      end
    end

    context 'when conversation does not exist' do
      it 'returns an error' do
        result = service.show_conversation(999999)

        expect(result.success?).to be false
        expect(result.error).to eq("대화를 찾을 수 없습니다.")
      end
    end
  end

  describe '#find_or_create_conversation' do
    context 'when conversation does not exist' do
      it 'creates a new conversation' do
        expect {
          result = service.find_or_create_conversation(other_user.id)
          expect(result.success?).to be true
        }.to change(Conversation, :count).by(1)
      end

      it 'creates conversation with broadcast if provided' do
        broadcast = create(:broadcast)
        
        result = service.find_or_create_conversation(other_user.id, broadcast)

        expect(result.success?).to be true
        expect(result.conversation.broadcast_id).to eq(broadcast.id)
      end
    end

    context 'when conversation already exists' do
      let!(:existing_conversation) { create(:conversation, user_a: user, user_b: other_user) }

      it 'returns the existing conversation' do
        expect {
          result = service.find_or_create_conversation(other_user.id)
          expect(result.success?).to be true
          expect(result.conversation.id).to eq(existing_conversation.id)
        }.not_to change(Conversation, :count)
      end
    end

    context 'when trying to create conversation with self' do
      it 'returns an error' do
        result = service.find_or_create_conversation(user.id)

        expect(result.success?).to be false
        expect(result.error).to eq("자기 자신과는 대화할 수 없습니다.")
      end
    end
  end

  describe '#create_from_broadcast' do
    let(:broadcast) { create(:broadcast, user: other_user) }
    let(:recipient) { user }

    it 'creates a conversation from broadcast' do
      result = service.create_from_broadcast(broadcast, recipient.id)

      expect(result.success?).to be true
      expect(result.conversation.broadcast_id).to eq(broadcast.id)
    end

    it 'handles errors gracefully' do
      allow(Conversation).to receive(:create_from_broadcast).and_return(nil)

      result = service.create_from_broadcast(broadcast, recipient.id)

      expect(result.success?).to be false
      expect(result.error).to eq("브로드캐스트에서 대화 생성에 실패했습니다.")
    end
  end

  describe '#delete_conversation' do
    context 'when user is a participant' do
      it 'soft deletes the conversation for the user' do
        result = service.delete_conversation(conversation.id)

        expect(result.success?).to be true
        expect(result.message).to eq("대화방이 삭제되었습니다.")
        
        conversation.reload
        expect(conversation.deleted_by_a).to be true
      end
    end

    context 'when user is not a participant' do
      let(:other_conversation) { create(:conversation) }

      it 'returns an error' do
        result = service.delete_conversation(other_conversation.id)

        expect(result.success?).to be false
        expect(result.error).to eq("권한이 없습니다.")
      end
    end
  end

  describe '#toggle_favorite' do
    context 'when user is a participant' do
      it 'toggles favorite status' do
        # First toggle - set to true
        result = service.toggle_favorite(conversation.id)
        expect(result.success?).to be true
        conversation.reload
        expect(conversation.favorited_by_a).to be true

        # Second toggle - set to false
        result = service.toggle_favorite(conversation.id)
        expect(result.success?).to be true
        conversation.reload
        expect(conversation.favorited_by_a).to be false
      end

      it 'returns appropriate message' do
        result = service.toggle_favorite(conversation.id)
        expect(result.message).to eq("즐겨찾기 등록 완료")

        result = service.toggle_favorite(conversation.id)
        expect(result.message).to eq("즐겨찾기 해제 완료")
      end
    end

    context 'when user is not a participant' do
      let(:other_conversation) { create(:conversation) }

      it 'returns an error' do
        result = service.toggle_favorite(other_conversation.id)

        expect(result.success?).to be false
        expect(result.error).to eq("권한이 없습니다.")
      end
    end
  end

  describe '#unread_message_count' do
    let!(:conversation1) { create(:conversation, user_a: user, user_b: other_user, created_at: 2.hours.ago) }
    let!(:conversation2) { create(:conversation, user_a: other_user, user_b: user, created_at: 2.hours.ago) }

    before do
      # Create read and unread messages
      # conversation1: user is user_a, last_read_at_a = 45.minutes.ago
      #   - message at 1.hour.ago -> READ (before last_read_at_a)
      #   - message at 30.minutes.ago -> UNREAD (after last_read_at_a)
      create(:message, conversation: conversation1, sender: other_user, created_at: 1.hour.ago)
      create(:message, conversation: conversation1, sender: other_user, created_at: 30.minutes.ago)

      # conversation2: user is user_b, last_read_at_b = nil (defaults to conversation.created_at)
      #   - message at 20.minutes.ago -> UNREAD (after conversation.created_at)
      create(:message, conversation: conversation2, sender: other_user, created_at: 20.minutes.ago)

      # Mark first conversation as read 45 minutes ago
      conversation1.update(last_read_at_a: 45.minutes.ago)
    end

    it 'returns total unread message count' do
      result = service.unread_message_count

      expect(result.success?).to be true
      expect(result.message).to eq(2) # 1 from conversation1, 1 from conversation2
    end

    it 'excludes messages sent by the current user' do
      create(:message, conversation: conversation1, sender: user)

      result = service.unread_message_count

      expect(result.success?).to be true
      expect(result.message).to eq(2) # Still 2, own message not counted
    end
  end

  describe '#mark_as_read' do
    context 'when user is a participant' do
      it 'updates the last read timestamp' do
        travel_to Time.current do
          result = service.mark_as_read(conversation.id)

          expect(result.success?).to be true
          conversation.reload
          expect(conversation.last_read_at_a).to be_within(1.second).of(Time.current)
        end
      end

      it 'updates correct field based on user position' do
        # Create conversation where current user is user_b
        conv = create(:conversation, user_a: other_user, user_b: user)

        travel_to Time.current do
          result = service.mark_as_read(conv.id)

          expect(result.success?).to be true
          conv.reload
          expect(conv.last_read_at_b).to be_within(1.second).of(Time.current)
        end
      end
    end

    context 'when user is not a participant' do
      let(:other_conversation) { create(:conversation) }

      it 'returns an error' do
        result = service.mark_as_read(other_conversation.id)

        expect(result.success?).to be false
        expect(result.error).to eq("권한이 없습니다.")
      end
    end
  end
end