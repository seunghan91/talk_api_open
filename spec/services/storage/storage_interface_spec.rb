require 'rails_helper'
require_relative '../../../app/services/storage/local_storage_service'
require_relative '../../../app/services/storage/s3_storage_service'
require_relative '../../../app/services/storage/memory_storage_service'

# Shared examples for storage services that actually track state (MemoryStorageService, LocalStorageService)
RSpec.shared_examples 'stateful_storage_service' do
  let(:test_file) do
    double('file',
      read: 'test content',
      original_filename: 'test.txt',
      content_type: 'text/plain'
    )
  end

  describe '#upload' do
    it '파일을 업로드하고 URL을 반환한다' do
      result = subject.upload(
        file: test_file,
        key: 'test/file.txt',
        content_type: 'text/plain'
      )

      expect(result).to be_a(String)
      expect(result).to include('file.txt')
    end

    it '필수 파라미터가 없으면 에러를 발생시킨다' do
      expect {
        subject.upload(file: nil, key: 'test.txt')
      }.to raise_error(ArgumentError)
    end
  end

  describe '#download' do
    it '파일을 다운로드한다' do
      # 먼저 업로드
      url = subject.upload(
        file: test_file,
        key: 'test/download.txt',
        content_type: 'text/plain'
      )

      # 다운로드
      content = subject.download(key: 'test/download.txt')
      expect(content).to eq('test content')
    end

    it '존재하지 않는 파일은 nil을 반환한다' do
      content = subject.download(key: 'non-existent.txt')
      expect(content).to be_nil
    end
  end

  describe '#delete' do
    it '파일을 삭제한다' do
      # 먼저 업로드
      subject.upload(
        file: test_file,
        key: 'test/delete.txt',
        content_type: 'text/plain'
      )

      # 삭제
      result = subject.delete(key: 'test/delete.txt')
      expect(result).to be true

      # 삭제 확인
      content = subject.download(key: 'test/delete.txt')
      expect(content).to be_nil
    end
  end

  describe '#exists?' do
    it '파일 존재 여부를 확인한다' do
      # 업로드 전
      expect(subject.exists?(key: 'test/exists.txt')).to be false

      # 업로드
      subject.upload(
        file: test_file,
        key: 'test/exists.txt',
        content_type: 'text/plain'
      )

      # 업로드 후
      expect(subject.exists?(key: 'test/exists.txt')).to be true
    end
  end

  describe '#url' do
    it '파일의 URL을 반환한다' do
      subject.upload(
        file: test_file,
        key: 'test/url.txt',
        content_type: 'text/plain'
      )

      url = subject.url(key: 'test/url.txt')
      expect(url).to be_a(String)
      expect(url).to include('url.txt')
    end
  end
end

# Shared examples for mock storage services (S3StorageService - development mock without real S3)
RSpec.shared_examples 'mock_storage_service' do
  let(:test_file) do
    double('file',
      read: 'test content',
      original_filename: 'test.txt',
      content_type: 'text/plain'
    )
  end

  describe '#upload' do
    it '파일을 업로드하고 URL을 반환한다' do
      result = subject.upload(
        file: test_file,
        key: 'test/file.txt',
        content_type: 'text/plain'
      )

      expect(result).to be_a(String)
      expect(result).to include('file.txt')
    end

    it '필수 파라미터가 없으면 에러를 발생시킨다' do
      expect {
        subject.upload(file: nil, key: 'test.txt')
      }.to raise_error(ArgumentError)
    end
  end

  describe '#download' do
    it '파일 키에 대한 모의 컨텐츠를 반환한다' do
      content = subject.download(key: 'test/download.txt')
      expect(content).to be_a(String)
    end
  end

  describe '#delete' do
    it '삭제 성공을 반환한다' do
      result = subject.delete(key: 'test/delete.txt')
      expect(result).to be true
    end
  end

  describe '#exists?' do
    it '파일 존재 여부를 반환한다 (모의 구현은 항상 true)' do
      expect(subject.exists?(key: 'test/exists.txt')).to be true
    end
  end

  describe '#url' do
    it '파일의 URL을 반환한다' do
      url = subject.url(key: 'test/url.txt')
      expect(url).to be_a(String)
      expect(url).to include('url.txt')
    end
  end
end

# 각 구현체 테스트
RSpec.describe LocalStorageService do
  # 테스트 전에 테스트 파일들 정리
  let(:test_base_path) { Rails.root.join('tmp', 'test_uploads') }

  subject { described_class.new(base_path: test_base_path) }

  before(:each) do
    FileUtils.rm_rf(test_base_path)
    FileUtils.mkdir_p(test_base_path)
  end

  after(:each) do
    FileUtils.rm_rf(test_base_path)
  end

  it_behaves_like 'stateful_storage_service'

  describe '로컬 스토리지 특화 기능' do
    it '파일 시스템에 파일을 저장한다' do
      path = test_base_path.join('test/local.txt')

      subject.upload(
        file: double('file', read: 'local content', original_filename: 'local.txt'),
        key: 'test/local.txt',
        content_type: 'text/plain'
      )

      expect(File.exist?(path)).to be true
    end
  end
end

RSpec.describe S3StorageService do
  # S3StorageService는 실제 S3 연결 없이 동작하는 모의 구현이므로
  # mock_storage_service 공유 예제를 사용
  it_behaves_like 'mock_storage_service'

  describe 'S3 특화 기능' do
    it 'S3 버킷에 파일을 업로드한다' do
      # S3 특화 테스트
      expect(subject).to respond_to(:bucket_name)
      expect(subject).to respond_to(:presigned_url)
    end

    it 'presigned URL을 생성한다' do
      url = subject.presigned_url(key: 'test/file.txt', expires_in: 3600)
      expect(url).to be_a(String)
      expect(url).to include('X-Amz-Expires=3600')
    end

    it '올바른 S3 URL 형식을 반환한다' do
      url = subject.url(key: 'test/file.txt')
      expect(url).to match(%r{https://s3\.amazonaws\.com/.*/test/file\.txt})
    end
  end
end

RSpec.describe MemoryStorageService do
  it_behaves_like 'stateful_storage_service'

  describe '메모리 스토리지 특화 기능' do
    it '메모리에 파일을 저장한다' do
      subject.upload(
        file: double('file', read: 'memory content', original_filename: 'memory.txt'),
        key: 'test/memory.txt',
        content_type: 'text/plain'
      )

      expect(subject.storage_size).to be > 0
    end
  end
end
