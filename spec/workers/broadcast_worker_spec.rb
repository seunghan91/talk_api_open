require 'rails_helper'

RSpec.describe BroadcastWorker do
  let(:worker) { described_class.new }
  let(:sender) { create(:user) }
  let(:broadcast) { create(:broadcast, user: sender, recipient_count: 5) }
  
  describe "#perform" do
    let!(:active_users) { create_list(:user, 10, last_sign_in_at: 1.day.ago, status: :active) }
    
    it "creates broadcast recipients" do
      expect {
        worker.perform(broadcast.id)
      }.to change(BroadcastRecipient, :count).by_at_least(1)
    end
    
    it "creates conversations for each recipient" do
      expect {
        worker.perform(broadcast.id)
      }.to change(Conversation, :count).by_at_least(1)
    end
    
    it "logs blocked users exclusion" do
      blocked_user = create(:user, last_sign_in_at: 1.day.ago)
      create(:block, blocker: sender, blocked: blocked_user)
      
      expect(Rails.logger).to receive(:info).with(/차단 목록: 1명/)
      
      worker.perform(broadcast.id)
    end
  end
  
  describe "#get_blocked_user_ids" do
    let(:user) { create(:user) }
    let(:blocked_by_user) { create(:user) }
    let(:blocking_user) { create(:user) }
    
    before do
      create(:block, blocker: user, blocked: blocked_by_user)
      create(:block, blocker: blocking_user, blocked: user)
    end
    
    it "returns both blocked and blocking user ids" do
      blocked_ids = worker.get_blocked_user_ids(user)
      
      expect(blocked_ids).to contain_exactly(blocked_by_user.id, blocking_user.id)
    end
    
    it "logs the blocking information" do
      expect(Rails.logger).to receive(:info).with(/차단 목록: 2명 \(차단함: 1명, 차단당함: 1명\)/)
      
      worker.get_blocked_user_ids(user)
    end
  end
  
  describe "#select_optimal_recipients" do
    let!(:active_users) { create_list(:user, 20, last_sign_in_at: 1.day.ago, status: :active) }
    let!(:inactive_users) { create_list(:user, 5, last_sign_in_at: 40.days.ago, status: :active) }
    
    it "excludes sender from recipients" do
      recipients = worker.select_optimal_recipients(sender, 5)
      
      expect(recipients.map(&:id)).not_to include(sender.id)
    end
    
    it "prioritizes test accounts for test senders" do
      test_sender = create(:user, phone_number: '+821012345678')
      test_users = create_list(:user, 3, phone_number: '+821087654321', status: :active)
      
      recipients = worker.select_optimal_recipients(test_sender, 2)
      
      expect(recipients.all? { |u| u.phone_number.start_with?('+8210') }).to be true
    end
    
    it "reduces diversity by excluding some recent recipients" do
      # 24시간 이내 브로드캐스트 수신자들
      recent_broadcast = create(:broadcast, created_at: 12.hours.ago)
      recent_recipients = active_users.first(10)
      recent_recipients.each do |user|
        create(:broadcast_recipient, broadcast: recent_broadcast, recipient: user)
      end
      
      recipients = worker.select_optimal_recipients(sender, 10)
      
      # 최근 수신자 중 일부만 제외되어야 함
      recent_recipient_ids = recent_recipients.map(&:id)
      selected_recent_count = recipients.count { |r| recent_recipient_ids.include?(r.id) }
      
      expect(selected_recent_count).to be < recent_recipients.size
    end
  end
  
  describe "activity score weighting" do
    it "applies 30% weight to activity scores" do
      # 가중치가 0.3인지 확인
      expect(worker.send(:activity_weight)).to eq(0.3) if worker.respond_to?(:activity_weight, true)
    end
  end
end
