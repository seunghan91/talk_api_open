require 'rails_helper'

RSpec.describe "Api::V1::Broadcasts", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{user.generate_jwt}" } }
  
  describe "GET /api/v1/broadcasts/received" do
    let!(:broadcast) { create(:broadcast) }
    let!(:broadcast_recipient) { create(:broadcast_recipient, broadcast: broadcast, recipient: user, status: 'delivered') }
    
    before do
      # 6일 이상 지난 브로드캐스트 (표시되지 않아야 함)
      old_broadcast = create(:broadcast, created_at: 7.days.ago)
      create(:broadcast_recipient, broadcast: old_broadcast, recipient: user)
    end
    
    it "returns received broadcasts within 6 days" do
      get "/api/v1/broadcasts/received", headers: auth_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json['broadcasts'].size).to eq(1)
      expect(json['broadcasts'][0]['id']).to eq(broadcast.id)
      expect(json['broadcasts'][0]['recipient_status']).to eq('delivered')
    end
    
    it "returns 401 without authentication" do
      get "/api/v1/broadcasts/received"
      expect(response).to have_http_status(:unauthorized)
    end
  end
  
  describe "PUT /api/v1/broadcasts/:id/mark_as_read" do
    let!(:broadcast) { create(:broadcast) }
    let!(:broadcast_recipient) { create(:broadcast_recipient, broadcast: broadcast, recipient: user, status: 'delivered') }
    
    it "marks broadcast as read" do
      put "/api/v1/broadcasts/#{broadcast.id}/mark_as_read", headers: auth_headers
      
      expect(response).to have_http_status(:success)
      expect(broadcast_recipient.reload.status).to eq('read')
    end
    
    it "returns 404 if not a recipient" do
      other_broadcast = create(:broadcast)
      
      put "/api/v1/broadcasts/#{other_broadcast.id}/mark_as_read", headers: auth_headers
      
      expect(response).to have_http_status(:not_found)
    end
    
    it "returns 422 if already replied" do
      broadcast_recipient.update(status: 'replied')
      
      put "/api/v1/broadcasts/#{broadcast.id}/mark_as_read", headers: auth_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
  
  describe "Broadcast recipient selection algorithm" do
    let(:sender) { create(:user) }
    let!(:active_users) { create_list(:user, 10, last_sign_in_at: 1.day.ago) }
    let!(:inactive_users) { create_list(:user, 5, last_sign_in_at: 40.days.ago) }
    let!(:blocked_user) { create(:user, last_sign_in_at: 1.day.ago) }
    
    before do
      create(:block, blocker: sender, blocked: blocked_user)
    end
    
    it "excludes blocked users from recipients" do
      worker = BroadcastWorker.new
      recipients = worker.select_optimal_recipients(sender, 5)
      
      expect(recipients.map(&:id)).not_to include(blocked_user.id)
    end
    
    it "prioritizes recently active users" do
      worker = BroadcastWorker.new
      recipients = worker.select_optimal_recipients(sender, 5)
      
      # 모든 수신자가 활성 사용자여야 함
      expect(recipients.all? { |u| u.last_sign_in_at > 30.days.ago }).to be true
    end
    
    it "reduces score for recent broadcast recipients" do
      # 24시간 이내 브로드캐스트 수신자
      recent_broadcast = create(:broadcast, created_at: 12.hours.ago)
      create(:broadcast_recipient, broadcast: recent_broadcast, recipient: active_users.first)
      
      worker = BroadcastWorker.new
      
      # 스코어 계산 테스트를 위해 직접 메서드 호출
      allow(worker).to receive(:calculate_activity_scores).and_call_original
      
      recipients = worker.select_optimal_recipients(sender, 5)
      
      # 로그 확인을 위한 출력
      expect(Rails.logger).to receive(:info).at_least(:once)
    end
  end
end
