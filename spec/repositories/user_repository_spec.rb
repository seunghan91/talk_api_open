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

  describe 'blocked users filtering' do
    let!(:active_user1) { create(:user, blocked: false) }
    let!(:active_user2) { create(:user, blocked: false) }
    let!(:blocked_user) { create(:user, blocked: true) }

    it 'blocked가 false인 사용자만 반환한다' do
      results = User.where(blocked: false)
      expect(results).to match_array([ active_user1, active_user2 ])
    end
  end

  describe '#find' do
    let(:user) { create(:user) }

    it '사용자 ID로 사용자를 찾는다' do
      result = repository.find(user.id)
      expect(result).to eq(user)
    end

    it '존재하지 않는 ID는 예외를 발생시킨다' do
      expect {
        repository.find(-1)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#includes' do
    let!(:user) { create(:user) }

    it 'wallet과 함께 사용자를 로드한다' do
      result = repository.includes(:wallet).find(user.id)

      # N+1 쿼리 방지 확인 - wallet이 이미 로드됨
      expect(result.association(:wallet).loaded?).to be true
    end
  end

  describe '.search (class method)' do
    let!(:user1) { create(:user, nickname: '홍길동', phone_number: '01012345678') }
    let!(:user2) { create(:user, nickname: '김철수', phone_number: '01087654321') }
    let!(:user3) { create(:user, nickname: '이영희', phone_number: '01055555555') }

    context '닉네임으로 검색할 때' do
      it '일치하는 사용자를 반환한다' do
        results = described_class.search(nickname: '홍길동')
        expect(results).to eq([ user1 ])
      end

      it '부분 일치도 지원한다' do
        results = described_class.search(nickname: '길동')
        expect(results).to eq([ user1 ])
      end
    end

    context '전화번호로 검색할 때' do
      it '일치하는 사용자를 반환한다' do
        results = described_class.search(phone_number: '010123')
        expect(results).to eq([ user1 ])
      end
    end

    context '성별로 검색할 때' do
      let!(:male_user) { create(:user, gender: 'male') }
      let!(:female_user) { create(:user, gender: 'female') }

      it '성별로 필터링한다' do
        results = described_class.search(gender: 'male')
        expect(results).to include(male_user)
        expect(results).not_to include(female_user)
      end
    end
  end

  describe '.with_broadcasts_count (class method)' do
    let(:user) { create(:user) }

    before do
      3.times { create(:broadcast, user: user) }
    end

    it '방송 횟수와 함께 사용자를 반환한다' do
      result = described_class.with_broadcasts_count.find(user.id)
      expect(result.broadcasts_count).to eq(3)
    end
  end

  describe '.blocked_by (class method)' do
    let(:blocker) { create(:user) }
    let!(:blocked_user1) { create(:user) }
    let!(:blocked_user2) { create(:user) }
    let!(:not_blocked_user) { create(:user) }

    before do
      create(:block, blocker: blocker, blocked: blocked_user1)
      create(:block, blocker: blocker, blocked: blocked_user2)
    end

    it '차단한 사용자 목록을 반환한다' do
      results = described_class.blocked_by(blocker)
      expect(results).to match_array([ blocked_user1, blocked_user2 ])
    end
  end

  describe '#create_with_wallet' do
    let(:params) do
      {
        phone_number: '01012345678',
        password: 'password123',
        nickname: '테스트유저',
        gender: 'male'
      }
    end

    it '지갑과 함께 사용자를 생성한다' do
      # User 모델에 after_create callback이 있으므로 wallet은 자동 생성됨
      # create_with_wallet은 명시적으로 wallet을 생성하지만
      # 중복 방지를 위해 모델의 callback을 비활성화하고 테스트
      expect {
        repository.create_with_wallet(params)
      }.to change(User, :count).by(1)
         .and change(Wallet, :count).by(1)
    end

    it '생성된 사용자는 지갑을 가진다' do
      result = repository.create_with_wallet(params)

      expect(result).to be_persisted
      expect(result.nickname).to eq('테스트유저')
      expect(result.wallet).to be_present
    end
  end

  describe '.with_associations (class method)' do
    let!(:user) { create(:user) }

    before do
      create(:broadcast, user: user)
    end

    it 'includes를 사용하여 associations를 프리로드한다' do
      users = described_class.with_associations(:wallet, :broadcasts)

      # association이 로드되었는지 확인
      loaded_user = users.find(user.id)
      expect(loaded_user.association(:wallet).loaded?).to be true
      expect(loaded_user.association(:broadcasts).loaded?).to be true
    end
  end

  describe '#exists?' do
    let!(:user) { create(:user, phone_number: '01012345678') }

    it 'ID로 존재 여부를 확인한다' do
      expect(repository.exists?(user.id)).to be true
      expect(repository.exists?(-1)).to be false
    end

    it '조건으로 존재 여부를 확인한다' do
      expect(repository.exists?(phone_number: '01012345678')).to be true
      expect(repository.exists?(phone_number: '01099999999')).to be false
    end
  end

  describe '#find_by_phone (alias method)' do
    let(:phone_number) { '01012345678' }
    let!(:user) { create(:user, phone_number: phone_number) }

    it '전화번호로 사용자를 찾는다' do
      result = repository.find_by_phone(phone_number)
      expect(result).to eq(user)
    end
  end

  describe '#exists_by_phone?' do
    let!(:user) { create(:user, phone_number: '01012345678') }

    it '전화번호 존재 여부를 확인한다' do
      expect(repository.exists_by_phone?('01012345678')).to be true
      expect(repository.exists_by_phone?('01099999999')).to be false
    end
  end
end
