# spec/repositories/message_repository_spec.rb
require 'rails_helper'

RSpec.describe MessageRepository do
  let(:repository) { described_class.new }
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:conversation) { create(:conversation, user_a: user, user_b: other_user) }
  
  describe '#create!' do
    let(:attributes) do
      {
        conversation: conversation,
        sender: user,
        message_type: 'voice',
        read: false
      }
    end

    it '메시지를 생성한다' do
      expect {
        repository.create!(attributes)
      }.to change(Message, :count).by(1)
    end

    it '생성된 메시지를 반환한다' do
      message = repository.create!(attributes)
      
      expect(message).to be_a(Message)
      expect(message.conversation).to eq(conversation)
      expect(message.sender).to eq(user)
      expect(message.message_type).to eq('voice')
    end

    context '잘못된 속성으로 생성 시' do
      let(:invalid_attributes) { { conversation: nil } }

      it 'ActiveRecord::RecordInvalid 에러를 발생시킨다' do
        expect {
          repository.create!(invalid_attributes)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#find_by_id' do
    let!(:message) { create(:message, conversation: conversation, sender: user) }

    it '존재하는 메시지를 반환한다' do
      result = repository.find_by_id(message.id)
      expect(result).to eq(message)
    end

    it '존재하지 않는 경우 nil을 반환한다' do
      result = repository.find_by_id(999999)
      expect(result).to be_nil
    end
  end

  describe '#by_conversation' do
    let!(:messages) do
      5.times.map do |i|
        create(:message, 
          conversation: conversation, 
          sender: [user, other_user].sample,
          created_at: i.hours.ago
        )
      end
    end
    let!(:other_conversation_message) { create(:message) }

    it '특정 대화의 메시지만 반환한다' do
      results = repository.by_conversation(conversation)
      
      expect(results.count).to eq(5)
      expect(results).not_to include(other_conversation_message)
    end

    it '최신 순으로 정렬된다' do
      results = repository.by_conversation(conversation)
      
      expect(results.first.created_at).to be > results.last.created_at
    end

    it '제한된 수만큼 반환한다' do
      results = repository.by_conversation(conversation, limit: 3)
      
      expect(results.count).to eq(3)
    end

    it 'sender를 eager loading한다' do
      # Load conversation messages - should include sender in query
      messages = repository.by_conversation(conversation)

      # Access senders without triggering N+1 queries
      # The includes(:sender) in the repository should preload senders
      expect(messages.first.association(:sender).loaded?).to be true
    end
  end

  describe '#unread_for_user' do
    let!(:unread_received) { create(:message, conversation: conversation, sender: other_user, read: false) }
    let!(:read_received) { create(:message, conversation: conversation, sender: other_user, read: true) }
    let!(:sent_message) { create(:message, conversation: conversation, sender: user, read: false) }

    it '사용자가 받은 읽지 않은 메시지만 반환한다' do
      results = repository.unread_for_user(user)
      
      expect(results).to include(unread_received)
      expect(results).not_to include(read_received)
      expect(results).not_to include(sent_message)
    end
  end

  describe '#mark_as_read' do
    let!(:unread_messages) do
      3.times.map { create(:message, conversation: conversation, read: false) }
    end

    it '지정된 메시지들을 읽음 처리한다' do
      message_ids = unread_messages.map(&:id)
      
      expect {
        repository.mark_as_read(message_ids)
      }.to change {
        Message.where(id: message_ids, read: true).count
      }.from(0).to(3)
    end

    it '업데이트된 수를 반환한다' do
      message_ids = unread_messages.map(&:id)
      result = repository.mark_as_read(message_ids)
      
      expect(result).to eq(3)
    end
  end

  describe '#last_message_for_conversation' do
    let!(:old_message) { create(:message, conversation: conversation, created_at: 2.hours.ago) }
    let!(:new_message) { create(:message, conversation: conversation, created_at: 1.hour.ago) }

    it '가장 최근 메시지를 반환한다' do
      result = repository.last_message_for_conversation(conversation)
      expect(result).to eq(new_message)
    end

    context '메시지가 없는 경우' do
      let(:empty_conversation) { create(:conversation) }

      it 'nil을 반환한다' do
        result = repository.last_message_for_conversation(empty_conversation)
        expect(result).to be_nil
      end
    end
  end

  describe '#statistics' do
    before do
      # 음성 메시지 3개 (1개 읽음)
      create_list(:message, 2, message_type: 'voice', read: false, created_at: 1.day.ago)
      create(:message, message_type: 'voice', read: true, created_at: 1.day.ago)
      
      # 텍스트 메시지 2개 (모두 읽지 않음)
      create_list(:message, 2, message_type: 'text', read: false, created_at: 1.day.ago)
      
      # 오래된 메시지 (통계에서 제외)
      create(:message, created_at: 40.days.ago)
    end

    it '전체 통계를 반환한다' do
      stats = repository.statistics
      
      expect(stats[:total_count]).to eq(5)
      expect(stats[:voice_count]).to eq(3)
      expect(stats[:text_count]).to eq(2)
      expect(stats[:read_count]).to eq(1)
      expect(stats[:unread_count]).to eq(4)
    end

    context '특정 사용자 통계' do
      let(:sender) { create(:user) }
      
      before do
        create_list(:message, 2, sender: sender, created_at: 1.day.ago)
      end

      it '해당 사용자가 보낸 메시지만 집계한다' do
        stats = repository.statistics(user: sender)
        
        expect(stats[:total_count]).to eq(2)
      end
    end

    context '기간 설정' do
      it '지정된 기간의 메시지만 집계한다' do
        stats = repository.statistics(from: 7.days.ago, to: Time.current)
        
        expect(stats[:total_count]).to eq(5) # 오래된 메시지 제외
      end
    end
  end

  describe '#search' do
    it '검색 쿼리를 실행할 수 있다' do
      expect { repository.search('hello').to_a }.not_to raise_error
      expect(repository.search('hello')).to be_a(ActiveRecord::Relation)
    end
  end

  describe '.by_conversation (클래스 메서드)' do
    let!(:message) { create(:message, conversation: conversation) }

    it '인스턴스 메서드와 동일하게 동작한다' do
      results = described_class.by_conversation(conversation)
      
      expect(results).to include(message)
    end
  end
end 
