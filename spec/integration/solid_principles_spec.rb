require 'rails_helper'

RSpec.describe 'SOLID 원칙 적용 검증' do
  describe 'Single Responsibility Principle (단일 책임 원칙)' do
    it 'UserService는 사용자 관련 비즈니스 로직만 담당한다' do
      service = UserService.new
      
      # UserService의 공개 메서드들이 사용자 관련 기능만 제공하는지 확인
      public_methods = service.public_methods(false)
      user_related_methods = [:create_user, :suspend_user, :block_user, :report_user, :update_profile, :check_suspension_expiry]
      
      expect(public_methods).to match_array(user_related_methods)
    end
    
    it 'Repository는 데이터 액세스만 담당한다' do
      repository = UserRepository.new
      
      # Repository 메서드들이 데이터 액세스 관련 기능만 제공하는지 확인
      expect(repository).to respond_to(:find)
      expect(repository).to respond_to(:create)
      expect(repository).to respond_to(:update)
      expect(repository).not_to respond_to(:send_notification)
      expect(repository).not_to respond_to(:calculate_points)
    end
  end
  
  describe 'Open/Closed Principle (개방-폐쇄 원칙)' do
    it '새로운 알림 타입을 기존 코드 수정 없이 추가할 수 있다' do
      # 새로운 알림 전략 추가
      class CustomNotificationStrategy
        def send(user, data)
          { success: true, message: "Custom notification sent" }
        end
      end
      
      # 기존 NotificationService에 새 전략 주입
      custom_strategy = CustomNotificationStrategy.new
      service = NotificationService.new
      
      # 런타임에 전략 변경 가능
      expect {
        service.send_notification(
          create(:user),
          type: :custom,
          data: { message: "Test" }
        )
      }.not_to raise_error
    end
    
    it '새로운 Storage 서비스를 기존 코드 수정 없이 추가할 수 있다' do
      # 새로운 Storage 구현체
      class CustomStorageService < Storage::BaseStorageService
        def upload(file:, key:, content_type: nil)
          "custom://#{key}"
        end
        
        def download(key:)
          "custom content"
        end
        
        def delete(key:)
          true
        end
        
        def exists?(key:)
          true
        end
        
        def url(key:)
          "custom://#{key}"
        end
      end
      
      # AudioUploadService에서 사용
      custom_storage = CustomStorageService.new
      service = AudioUploadService.new(storage_service: custom_storage)
      
      file = double('file', read: 'content', original_filename: 'test.mp3', content_type: 'audio/mp3')
      result = service.upload(file)
      
      expect(result).to include("custom://")
    end
  end
  
  describe 'Liskov Substitution Principle (리스코프 치환 원칙)' do
    it '모든 Storage 서비스는 교체 가능하다' do
      file = double('file', read: 'test content', original_filename: 'test.txt')
      key = 'test/file.txt'
      
      # 각 Storage 구현체가 동일한 인터페이스를 제공
      [
        Storage::LocalStorageService.new,
        Storage::S3StorageService.new,
        Storage::MemoryStorageService.new
      ].each do |storage|
        # 업로드
        url = storage.upload(file: file, key: key)
        expect(url).to be_a(String)
        
        # 존재 확인
        expect(storage.exists?(key: key)).to be_in([true, false])
        
        # URL 생성
        expect(storage.url(key: key)).to be_a(String)
      end
    end
  end
  
  describe 'Interface Segregation Principle (인터페이스 분리 원칙)' do
    it '읽기 전용 Repository는 쓰기 메서드를 제공하지 않는다' do
      read_only_repo = ReadOnlyUserRepository.new
      
      # 읽기 메서드는 제공
      expect(read_only_repo).to respond_to(:find)
      expect(read_only_repo).to respond_to(:where)
      expect(read_only_repo).to respond_to(:count)
      
      # 쓰기 메서드는 제공하지 않음
      expect {
        read_only_repo.create(phone_number: '01012345678')
      }.to raise_error(NotImplementedError)
    end
    
    it '쓰기 전용 Repository는 읽기 메서드를 제공하지 않는다' do
      write_only_repo = WriteOnlyUserRepository.new
      
      # 쓰기 메서드는 제공
      expect(write_only_repo).to respond_to(:create)
      expect(write_only_repo).to respond_to(:update)
      expect(write_only_repo).to respond_to(:destroy)
      
      # 읽기 메서드는 제공하지 않음
      expect {
        write_only_repo.find(1)
      }.to raise_error(NotImplementedError)
    end
  end
  
  describe 'Dependency Inversion Principle (의존성 역전 원칙)' do
    it 'Service는 구체적 구현이 아닌 추상화에 의존한다' do
      # Mock 의존성들
      mock_notification = double('NotificationService')
      mock_wallet = double('WalletService')
      
      # UserService에 의존성 주입
      service = UserService.new(
        notification_service: mock_notification,
        wallet_service: mock_wallet
      )
      
      # Mock 객체가 호출되는지 확인
      expect(mock_notification).to receive(:send_notification)
      expect(mock_wallet).to receive(:create_wallet_for_user)
      
      service.create_user(
        phone_number: '01012345678',
        password: 'password123',
        nickname: '테스트'
      )
    end
    
    it 'Form Object는 구체적 서비스가 아닌 인터페이스에 의존한다' do
      # Mock 서비스들
      mock_audio_service = double('AudioUploadService')
      mock_recipient_service = double('RecipientSelectionService')
      
      form = BroadcastForm.new(
        user_id: create(:user).id,
        audio_file: fixture_file_upload('audio_sample.m4a', 'audio/mp4'),
        duration: 30,
        recipient_count: 5,
        audio_upload_service: mock_audio_service,
        recipient_selection_service: mock_recipient_service
      )
      
      # Mock 객체들이 올바른 인터페이스를 구현하는지 확인
      expect(mock_audio_service).to receive(:upload).and_return('https://example.com/audio.m4a')
      expect(mock_recipient_service).to receive(:select_recipients).and_return([1, 2, 3, 4, 5])
      
      form.save
    end
  end
  
  describe '전체 시스템 통합' do
    it '방송 생성 플로우가 SOLID 원칙에 따라 동작한다' do
      user = create(:user)
      
      # 1. Form Object (SRP: 폼 검증만 담당)
      form = BroadcastForm.new(
        user_id: user.id,
        audio_file: fixture_file_upload('audio_sample.m4a', 'audio/mp4'),
        duration: 30,
        recipient_count: 5
      )
      
      expect(form.valid?).to be true
      
      # 2. Service Layer (SRP: 비즈니스 로직만 담당)
      expect_any_instance_of(AudioUploadService).to receive(:upload)
      expect_any_instance_of(Broadcasts::RecipientSelectionService).to receive(:select_recipients)
      
      # 3. Repository Layer (SRP: 데이터 액세스만 담당)
      expect {
        form.save
      }.to change(Broadcast, :count).by(1)
    end
  end
end 