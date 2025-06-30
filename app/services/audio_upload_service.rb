# frozen_string_literal: true

class AudioUploadService
  def initialize(storage_service: nil)
    @storage_service = storage_service || default_storage_service
  end
  
  def upload(file)
    validate_file!(file)
    
    # 파일 이름 생성
    filename = generate_filename(file)
    
    # S3 또는 로컬 스토리지에 업로드
    url = @storage_service.upload(
      file: file,
      key: "audio/broadcasts/#{filename}",
      content_type: file.content_type
    )
    
    # 오디오 메타데이터 추출 (옵션)
    extract_metadata(file) if respond_to?(:extract_metadata, true)
    
    url
  rescue => e
    Rails.logger.error "AudioUploadService#upload failed: #{e.message}"
    raise AudioUploadError, "오디오 업로드 실패: #{e.message}"
  end
  
  private
  
  def validate_file!(file)
    raise AudioUploadError, "파일이 없습니다" unless file.present?
    raise AudioUploadError, "유효하지 않은 파일입니다" unless file.respond_to?(:read)
  end
  
  def generate_filename(file)
    extension = File.extname(file.original_filename)
    "#{SecureRandom.uuid}#{extension}"
  end
  
  def default_storage_service
    if Rails.env.production?
      Storage::S3StorageService.new
    elsif Rails.env.test?
      Storage::MemoryStorageService.new
    else
      Storage::LocalStorageService.new
    end
  end
  
  class AudioUploadError < StandardError; end
end

 