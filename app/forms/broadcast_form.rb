# frozen_string_literal: true

class BroadcastForm
  include ActiveModel::Model
  
  # 입력 필드
  attr_accessor :user_id, :audio_file, :duration, :recipient_count, :recipient_filters
  
  # 의존성 주입
  attr_accessor :audio_upload_service, :recipient_selection_service, :broadcast_repository
  
  # 결과
  attr_reader :broadcast, :recipient_ids
  
  # 상수
  MAX_DURATION = 60 # seconds
  MAX_FILE_SIZE = 10.megabytes
  MAX_RECIPIENTS = 100
  ALLOWED_AUDIO_TYPES = %w[audio/mp4 audio/mpeg audio/x-m4a audio/wav].freeze
  
  # 유효성 검증
  validates :user_id, presence: true
  validates :audio_file, presence: true
  validates :duration, presence: true, 
            numericality: { greater_than: 0, less_than_or_equal_to: MAX_DURATION,
                          message: "#{MAX_DURATION}초 이하여야 합니다" }
  validates :recipient_count, presence: true,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_RECIPIENTS,
                          message: "#{MAX_RECIPIENTS}명 이하여야 합니다" }
  
  validate :validate_audio_file
  validate :validate_user_exists
  validate :validate_recipient_filters
  
  def initialize(attributes = {})
    super(attributes)
    @recipient_filters ||= { gender: 'all', age_group: 'all', region: 'all' }
    @audio_upload_service ||= AudioUploadService.new
    @recipient_selection_service ||= Broadcasts::RecipientSelectionService.new
    @broadcast_repository ||= BroadcastRepository.new
  end
  
  def save
    return false unless valid?
    
    ActiveRecord::Base.transaction do
      # 1. 오디오 파일 업로드
      audio_url = upload_audio_file
      
      # 2. 수신자 선택
      @recipient_ids = select_recipients
      
      # 3. 방송 생성
      @broadcast = create_broadcast(audio_url)
      
      # 4. 수신자 레코드 생성
      create_recipient_records
      
      # 5. 방송 작업 스케줄링
      schedule_broadcast_job
      
      true
    end
  rescue => e
    Rails.logger.error "BroadcastForm#save failed: #{e.message}"
    errors.add(:base, '방송 생성 중 오류가 발생했습니다')
    false
  end
  
  def to_broadcast_params
    {
      user_id: user_id,
      audio_url: @audio_url,
      duration: duration,
      status: :active,
      expires_at: 24.hours.from_now,
      metadata: {
        recipient_count: recipient_count,
        filters: recipient_filters
      }
    }
  end
  
  private
  
  def validate_audio_file
    return unless audio_file.present?
    
    # 파일 형식 검증
    unless ALLOWED_AUDIO_TYPES.include?(audio_file.content_type)
      errors.add(:audio_file, '지원하지 않는 파일 형식입니다')
    end
    
    # 파일 크기 검증
    if audio_file.size > MAX_FILE_SIZE
      errors.add(:audio_file, "파일 크기는 #{MAX_FILE_SIZE / 1.megabyte}MB 이하여야 합니다")
    end
  end
  
  def validate_user_exists
    return unless user_id.present?
    
    unless User.exists?(user_id)
      errors.add(:user_id, '존재하지 않는 사용자입니다')
    end
  end
  
  def validate_recipient_filters
    return unless recipient_filters.present?
    
    valid_genders = %w[all male female other]
    valid_age_groups = %w[all 10s 20s 30s 40s 50s 60s]
    valid_regions = %w[all 서울 경기 인천 부산 대구 광주 대전 울산 세종 강원 충북 충남 전북 전남 경북 경남 제주]
    
    unless valid_genders.include?(recipient_filters[:gender])
      errors.add(:recipient_filters, '유효하지 않은 성별 필터입니다')
    end
    
    unless valid_age_groups.include?(recipient_filters[:age_group])
      errors.add(:recipient_filters, '유효하지 않은 연령대 필터입니다')
    end
    
    unless valid_regions.include?(recipient_filters[:region])
      errors.add(:recipient_filters, '유효하지 않은 지역 필터입니다')
    end
  end
  
  def upload_audio_file
    @audio_url = audio_upload_service.upload(audio_file)
  end
  
  def select_recipients
    options = {
      count: recipient_count,
      filters: recipient_filters,
      exclude_user_id: user_id
    }
    
    recipient_selection_service.select_recipients(options)
  end
  
  def create_broadcast(audio_url)
    broadcast_params = to_broadcast_params.merge(audio_url: audio_url)
    Broadcast.create!(broadcast_params)
  end
  
  def create_recipient_records
    return unless @recipient_ids.present?
    
    recipient_records = @recipient_ids.map do |recipient_id|
      {
        broadcast_id: @broadcast.id,
        user_id: recipient_id,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    BroadcastRecipient.insert_all(recipient_records)
  end
  
  def schedule_broadcast_job
    BroadcastWorker.perform_async(@broadcast.id)
  end
  
  # 추가 헬퍼 메서드
  
  def user
    @user ||= User.find_by(id: user_id)
  end
  
  def filters_applied?
    recipient_filters.values.any? { |v| v != 'all' }
  end
  
  def estimated_reach
    return 0 unless valid?
    
    # 필터에 따른 예상 도달 수 계산
    query = User.active
    query = query.where(gender: recipient_filters[:gender]) unless recipient_filters[:gender] == 'all'
    query = query.where(age_group: recipient_filters[:age_group]) unless recipient_filters[:age_group] == 'all'
    query = query.where(region: recipient_filters[:region]) unless recipient_filters[:region] == 'all'
    
    [query.count, recipient_count].min
  end
end 