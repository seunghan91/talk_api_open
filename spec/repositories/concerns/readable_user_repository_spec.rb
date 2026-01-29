require 'rails_helper'

RSpec.describe ReadableUserRepository do
  let(:repository) { UserRepository.new }

  describe '읽기 전용 인터페이스' do
    let!(:user) { create(:user, phone_number: '01012345678') }

    it 'find 메서드를 제공한다' do
      expect(repository).to respond_to(:find)
      result = repository.find(user.id)
      expect(result).to eq(user)
    end

    it 'find_by_phone_number 메서드를 제공한다' do
      expect(repository).to respond_to(:find_by_phone_number)
      result = repository.find_by_phone_number('01012345678')
      expect(result).to eq(user)
    end

    it 'all 메서드를 제공한다' do
      expect(repository).to respond_to(:all)
      expect(repository.all).to include(user)
    end

    it 'where 메서드를 제공한다' do
      expect(repository).to respond_to(:where)
      result = repository.where(status: 'active')
      expect(result).to be_a(ActiveRecord::Relation)
    end

    it 'exists? 메서드를 제공한다' do
      expect(repository).to respond_to(:exists?)
      expect(repository.exists?(user.id)).to be true
    end

    it 'count 메서드를 제공한다' do
      expect(repository).to respond_to(:count)
      expect(repository.count).to be >= 1
    end

    # 참고: UserRepository는 ReadableUserRepository와 WritableUserRepository를 모두 포함하므로
    # 쓰기 메서드도 제공함. 읽기 전용 인터페이스 테스트는 ReadOnlyUserRepository에서 수행.
    it 'UserRepository는 읽기와 쓰기 메서드를 모두 제공한다' do
      expect(repository).to respond_to(:create)
      expect(repository).to respond_to(:update)
      expect(repository).to respond_to(:destroy)
    end
  end

  describe 'ReadOnlyRepository 구현' do
    let(:read_only_repo) { ReadOnlyUserRepository.new }

    it '읽기 전용 인터페이스만 구현한다' do
      expect(read_only_repo).to respond_to(:find)
      expect(read_only_repo).to respond_to(:find_by_phone_number)
      expect(read_only_repo).to respond_to(:all)
      expect(read_only_repo).to respond_to(:where)
      expect(read_only_repo).to respond_to(:exists?)
      expect(read_only_repo).to respond_to(:count)
    end

    it '쓰기 작업을 시도하면 에러를 발생시킨다' do
      expect {
        read_only_repo.create(phone_number: '01099999999')
      }.to raise_error(NotImplementedError)
    end
  end
end
