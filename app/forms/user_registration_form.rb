# frozen_string_literal: true

class UserRegistrationForm
  include ActiveModel::Model
  
  # 기본 정보
  attr_accessor :phone_number, :password, :password_confirmation
  attr_accessor :verification_code
  
  # 프로필 정보 (선택)
  attr_accessor :nickname, :gender, :age_group, :region
  attr_accessor :profile_image
  
  # 약관 동의
  attr_accessor :terms_agreed, :privacy_agreed, :marketing_agreed
  
  # 의존성
  attr_accessor :user_service, :phone_verification_service, :image_upload_service
  
  # 결과
  attr_reader :user
  
  # 유효성 검증
  validates :phone_number, presence: true, format: { with: /\A01\d{8,9}\z/, message: '올바른 전화번호 형식이 아닙니다' }
  validates :password, presence: true, length: { minimum: 6 }, confirmation: true
  validates :password_confirmation, presence: true
  validates :verification_code, presence: true, length: { is: 6 }
  validates :terms_agreed, acceptance: { message: '서비스 이용약관에 동의해주세요' }
  validates :privacy_agreed, acceptance: { message: '개인정보 처리방침에 동의해주세요' }
  
  # 선택적 프로필 검증
  validates :nickname, length: { minimum: 2, maximum: 20 }, allow_blank: true
  validates :gender, inclusion: { in: %w[male female other] }, allow_blank: true
  validates :age_group, inclusion: { in: %w[10s 20s 30s 40s 50s 60s] }, allow_blank: true
  validates :region, inclusion: { in: REGIONS }, allow_blank: true
  
  validate :validate_phone_verification
  validate :validate_unique_phone_number
  validate :validate_profile_image
  
  REGIONS = %w[서울 경기 인천 부산 대구 광주 대전 울산 세종 강원 충북 충남 전북 전남 경북 경남 제주].freeze
  
  def initialize(attributes = {})
    super(attributes)
    @user_service ||= UserService.new
    @phone_verification_service ||= PhoneVerificationService.new
    @image_upload_service ||= ImageUploadService.new
  end
  
  def save
    return false unless valid?
    
    ActiveRecord::Base.transaction do
      # 1. 전화번호 인증 확인
      verify_phone!
      
      # 2. 프로필 이미지 업로드 (있는 경우)
      profile_image_url = upload_profile_image if profile_image.present?
      
      # 3. 사용자 생성
      result = user_service.create_user(user_params.merge(profile_image_url: profile_image_url))
      
      if result.success?
        @user = result.user
        
        # 4. 마케팅 동의 저장
        save_marketing_consent if marketing_agreed
        
        # 5. 가입 완료 이벤트 발생
        trigger_registration_completed_event
        
        true
      else
        errors.add(:base, result.error)
        false
      end
    end
  rescue => e
    Rails.logger.error "UserRegistrationForm#save failed: #{e.message}"
    errors.add(:base, '회원가입 처리 중 오류가 발생했습니다')
    false
  end
  
  # 전화번호 인증 요청
  def request_verification_code
    return false unless phone_number.present?
    
    result = phone_verification_service.send_code(phone_number)
    
    if result[:success]
      true
    else
      errors.add(:phone_number, result[:error])
      false
    end
  end
  
  # 프로필 완성도 계산
  def profile_completion_percentage
    fields = [nickname, gender, age_group, region, profile_image]
    completed = fields.count(&:present?)
    (completed.to_f / fields.size * 100).round
  end
  
  private
  
  def validate_phone_verification
    return unless verification_code.present? && phone_number.present?
    
    unless phone_verification_service.valid_code?(phone_number, verification_code)
      errors.add(:verification_code, '인증 코드가 올바르지 않습니다')
    end
  end
  
  def validate_unique_phone_number
    return unless phone_number.present?
    
    if User.exists?(phone_number: phone_number)
      errors.add(:phone_number, '이미 가입된 전화번호입니다')
    end
  end
  
  def validate_profile_image
    return unless profile_image.present?
    
    # 이미지 형식 검증
    allowed_types = %w[image/jpeg image/png image/gif]
    unless allowed_types.include?(profile_image.content_type)
      errors.add(:profile_image, '지원하지 않는 이미지 형식입니다')
    end
    
    # 이미지 크기 검증
    if profile_image.size > 5.megabytes
      errors.add(:profile_image, '이미지 크기는 5MB 이하여야 합니다')
    end
  end
  
  def verify_phone!
    unless phone_verification_service.verify_and_consume!(phone_number, verification_code)
      raise ActiveRecord::Rollback
    end
  end
  
  def upload_profile_image
    image_upload_service.upload(
      profile_image,
      folder: 'profile_images'
    )
  end
  
  def user_params
    {
      phone_number: phone_number,
      password: password,
      nickname: nickname,
      gender: gender,
      age_group: age_group,
      region: region,
      terms_agreed_at: Time.current,
      privacy_agreed_at: Time.current
    }.compact
  end
  
  def save_marketing_consent
    MarketingConsent.create!(
      user: @user,
      consented: true,
      consented_at: Time.current,
      consent_type: 'registration'
    )
  end
  
  def trigger_registration_completed_event
    # 이벤트 발생 (예: 분석, 알림 등)
    AnalyticsService.track_event(
      'user_registered',
      user_id: @user.id,
      profile_completion: profile_completion_percentage,
      marketing_agreed: marketing_agreed
    )
    
    # 환영 알림은 UserService에서 처리
  end
end

# 이미지 업로드 서비스
class ImageUploadService
  def upload(file, folder:)
    # 실제 구현에서는 이미지 리사이징, 최적화 등 포함
    filename = "#{SecureRandom.uuid}#{File.extname(file.original_filename)}"
    path = "/uploads/#{folder}/#{filename}"
    
    # 실제 업로드 로직...
    
    path
  end
end 