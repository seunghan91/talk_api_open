# app/models/broadcast.rb
class Broadcast < ApplicationRecord
    belongs_to :user

    # 수신자 관계 추가
    has_many :broadcast_recipients, dependent: :destroy
    has_many :recipients, through: :broadcast_recipients, source: :user
    
    # 대화 및 메시지 관계 추가
    has_many :conversations, dependent: :restrict_with_error
    has_many :messages, dependent: :restrict_with_error

    # 음성 파일 첨부
    has_one_attached :audio

    # 음성 파일 변경 시 duration 설정하는 콜백 추가
    after_save :set_duration_from_audio, if: -> { audio.attached? && saved_change_to_audio_attachment? }

    # 유효성 검증 추가
    validates :user_id, presence: true
    # validates :audio, presence: true # 시드 데이터 생성을 위해 일시적으로 주석 처리
    validates :content, length: { maximum: 200 }, allow_blank: true

    # 인덱스드 필드
    before_create :set_expired_at

    # 만료 여부 확인
    def expired?
      expired_at < Time.current
    end

    # 만료 예정 확인 (24시간 이내)
    def expiring_soon?
      !expired? && expired_at < 24.hours.from_now
    end

    # 활성 상태 확인 - 만료되지 않은 경우에만 활성 상태로 간주
    def active?
      !expired?
    end
    
    # 오디오 URL 반환
    def audio_url
      audio.attached? ? Rails.application.routes.url_helpers.url_for(audio) : nil
    end
    
    # 수신자에게 브로드캐스트 전송
    def deliver_to_recipients(recipient_ids, max_count = 5)
      # 수신자 유효성 검사 및 제한
      recipients = User.where(id: recipient_ids)
                       .where.not(id: user_id)
                       .where(status: :active)
                       .limit(max_count)
      
      return false if recipients.empty?
      
      # 백그라운드 작업으로 처리
      BroadcastWorker.perform_async(id, recipients.count)
      
      true
    end

    # RailsAdmin 설정 (rails_admin gem이 활성화된 경우에만 사용)
    # rails_admin do
    #   list do
    #     field :id
    #     field :user
    #     field :created_at
    #     field :expired_at
    #     field :active
    #     field :voice_file
    #     field :expired? do
    #       formatted_value do
    #         bindings[:object].expired? ? '만료됨' : '활성'
    #       end
    #       sortable false
    #     end
    #     field :expiring_soon? do
    #       formatted_value do
    #         bindings[:object].expiring_soon? ? '만료 임박' : '-'
    #       end
    #       sortable false
    #     end
    #   end
    #
    #   show do
    #     field :id
    #     field :user
    #     field :created_at
    #     field :expired_at
    #     field :active
    #     field :voice_file
    #   end
    #
    #   edit do
    #     field :user
    #     field :active
    #     field :expired_at
    #   end
    # end

    private

    def set_expired_at
      self.expired_at ||= 6.days.from_now
    end
    
    # 음성 파일에서 재생 시간(duration) 설정
    def set_duration_from_audio
      return unless audio.attached?
      
      begin
        # 음성 파일 정보 추출
        audio_info = AudioProcessorService.get_audio_info(audio.blob.service.path_for(audio.key))
        
        if audio_info && audio_info[:duration]
          # 반올림하여 정수로 저장 (초 단위)
          update_column(:duration, audio_info[:duration].round)
          Rails.logger.info("브로드캐스트 ID #{id}의 duration 값을 #{duration}초로 설정")
        else
          Rails.logger.warn("브로드캐스트 ID #{id}의 오디오 파일에서 duration을 추출할 수 없음")
        end
      rescue => e
        # 오류가 발생해도 브로드캐스트 저장 자체는 실패하지 않도록 로그만 남김
        Rails.logger.error("브로드캐스트 ID #{id}의 duration 설정 중 오류 발생: #{e.message}")
      end
    end
end
