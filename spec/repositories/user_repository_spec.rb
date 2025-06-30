require 'rails_helper'

RSpec.describe UserRepository do
  let(:repository) { described_class.new }
  
  describe '#find_by_phone_number' do
    let(:phone_number) { '01012345678' }
    let!(:user) { create(:user, phone_number: phone_number) }
    
    it '전화번호로 사용자를 찾는다' do
      result = repository.find_by_phone_number(phone_number)
      expect(result).to eq(user)
    end
    
    it '존재하지 않는 번호는 nil을 반환한다' do
      result = repository.find_by_phone_number('01099999999')
      expect(result).to be_nil
    end
  end
  
  describe '#active_users' do
    let!(:active_user1) { create(:user, status: :active) }
    let!(:active_user2) { create(:user, status: :active) }
    let!(:suspended_user) { create(:user, status: :suspended) }
    let!(:deleted_user) { create(:user, status: :deleted) }
    
    it 'active 상태의 사용자만 반환한다' do
      results = repository.active_users
      expect(results).to match_array([active_user1, active_user2])
    end
  end
  
  describe '#find_with_profile' do
    let(:user) { create(:user) }
    
    it '프로필 정보와 함께 사용자를 로드한다' do
      result = repository.find_with_profile(user.id)
      
      # N+1 쿼리 방지 확인
      expect { 
        result.wallet
        result.user_suspensions
      }.not_to exceed_query_limit(0)
    end
  end
  
  describe '#search' do
    let!(:user1) { create(:user, nickname: '홍길동', phone_number: '01012345678') }
    let!(:user2) { create(:user, nickname: '김철수', phone_number: '01087654321') }
    let!(:user3) { create(:user, nickname: '이영희', phone_number: '01055555555') }
    
    context '닉네임으로 검색할 때' do
      it '일치하는 사용자를 반환한다' do
        results = repository.search(nickname: '홍길동')
        expect(results).to eq([user1])
      end
      
      it '부분 일치도 지원한다' do
        results = repository.search(nickname: '길동')
        expect(results).to eq([user1])
      end
    end
    
    context '전화번호로 검색할 때' do
      it '일치하는 사용자를 반환한다' do
        results = repository.search(phone_number: '010123')
        expect(results).to eq([user1])
      end
    end
    
    context '다중 조건으로 검색할 때' do
      it 'AND 조건으로 검색한다' do
        results = repository.search(
          gender: 'male',
          age_group: '20s',
          region: '서울'
        )
        
        expect(results).to all(have_attributes(
          gender: 'male',
          age_group: '20s',
          region: '서울'
        ))
      end
    end
  end
  
  describe '#recently_active' do
    let!(:recent_user) { create(:user, last_active_at: 1.hour.ago) }
    let!(:old_user) { create(:user, last_active_at: 1.month.ago) }
    let!(:very_recent_user) { create(:user, last_active_at: 5.minutes.ago) }
    
    it '최근 활동 순으로 정렬된 사용자를 반환한다' do
      results = repository.recently_active(limit: 2)
      expect(results).to eq([very_recent_user, recent_user])
    end
    
    it '지정된 기간 내의 사용자만 반환한다' do
      results = repository.recently_active(since: 1.day.ago)
      expect(results).to match_array([very_recent_user, recent_user])
    end
  end
  
  describe '#with_broadcasts_count' do
    let(:user) { create(:user) }
    
    before do
      3.times { create(:broadcast, user: user) }
    end
    
    it '방송 횟수와 함께 사용자를 반환한다' do
      result = repository.with_broadcasts_count.find(user.id)
      expect(result.broadcasts_count).to eq(3)
    end
  end
  
  describe '#blocked_by' do
    let(:blocker) { create(:user) }
    let!(:blocked_user1) { create(:user) }
    let!(:blocked_user2) { create(:user) }
    let!(:not_blocked_user) { create(:user) }
    
    before do
      create(:block, blocker: blocker, blocked: blocked_user1)
      create(:block, blocker: blocker, blocked: blocked_user2)
    end
    
    it '차단한 사용자 목록을 반환한다' do
      results = repository.blocked_by(blocker)
      expect(results).to match_array([blocked_user1, blocked_user2])
    end
  end
  
  describe '#create_with_profile' do
    let(:params) do
      {
        phone_number: '01012345678',
        password: 'password123',
        nickname: '테스트유저',
        gender: 'male',
        age_group: '20s',
        region: '서울'
      }
    end
    
    it '프로필과 함께 사용자를 생성한다' do
      result = repository.create_with_profile(params)
      
      expect(result).to be_persisted
      expect(result.nickname).to eq('테스트유저')
      expect(result.profile_completed).to be true
    end
    
    it '트랜잭션으로 처리한다' do
      allow_any_instance_of(User).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
      
      expect {
        repository.create_with_profile(params)
      }.to raise_error(ActiveRecord::RecordInvalid)
      
      expect(User.exists?(phone_number: params[:phone_number])).to be false
    end
  end
  
  describe 'Query Optimization' do
    it 'includes를 사용하여 N+1 쿼리를 방지한다' do
      users = repository.with_associations(:wallet, :broadcasts)
      
      expect {
        users.each { |u| u.wallet.balance }
        users.each { |u| u.broadcasts.count }
      }.not_to exceed_query_limit(2)
    end
  end
end 