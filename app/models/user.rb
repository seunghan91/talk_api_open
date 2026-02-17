# app/models/user.rb
class User < ApplicationRecord
  # 비밀번호 암호화 및 인증 기능
  has_secure_password validations: false

  encrypts :phone  # Rails 7 AR 암호화

  # status 필드를 attribute로 선언
  attribute :status, :integer, default: 0
  attribute :gender, :integer, default: 1
  # is_admin은 DB 컬럼으로 관리 (default: false)

  enum :gender, { unknown: 0, male: 1, female: 2 }, prefix: true, validate: true
  enum :status, { active: 0, suspended: 1, banned: 2 }, prefix: true, validate: true

  # Scope for active users (not blocked and verified)
  scope :active, -> { where(blocked: false, verified: true) }

  has_many :broadcasts, dependent: :destroy
  has_many :reports_as_reporter, class_name: "Report", foreign_key: :reporter_id
  has_many :reports_as_reported, class_name: "Report", foreign_key: :reported_id
  has_many :blocks_as_blocker, class_name: "Block", foreign_key: :blocker_id
  has_many :blocks_as_blocked, class_name: "Block", foreign_key: :blocked_id
  has_many :conversations_as_user_a, class_name: "Conversation", foreign_key: :user_a_id, dependent: :destroy
  has_many :conversations_as_user_b, class_name: "Conversation", foreign_key: :user_b_id, dependent: :destroy
  has_one :wallet, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :phone_verifications, dependent: :destroy
  has_one :latest_verification, -> { order(created_at: :desc) }, class_name: "PhoneVerification"
  has_many :user_suspensions, dependent: :destroy

  # 사용자 생성 후 지갑 자동 생성
  after_create :create_wallet_for_user

  # 전화번호 유효성 검증
  validates :phone_number, presence: true, uniqueness: true
  validate :valid_phone_number_format

  # 비밀번호 유효성 검사 (비밀번호가 있는 경우에만)
  validates :password, length: { minimum: 6 }, if: -> { password.present? }

  # 푸시 알림 설정
  attribute :push_enabled, :boolean, default: true
  attribute :broadcast_push_enabled, :boolean, default: true
  attribute :message_push_enabled, :boolean, default: true

  # DB에 push_token 칼럼이 있다면,
  # 굳이 attribute 선언 없이도 Rails가 string 타입을 자동 인식합니다.
  # 하지만 명시적으로 쓰고 싶다면:
  # attribute :push_token, :string

  # 전화번호 형식 검증 메서드
  def valid_phone_number_format
    unless phone_number.present? && (phone_number.match?(/^\d{10,11}$/))
      errors.add(:phone_number, "는 10-11자리 숫자여야 합니다.")
    end
  end

  # 신고 횟수 카운트 메서드
  def report_count
    reports_as_reported.count
  end

  # 차단 여부 확인 메서드
  def blocked?
    status_banned? || status_suspended?
  end

  # 관리자 여부 확인 메서드
  def admin?
    is_admin || id == 1  # ID가 1인 사용자는 기본 관리자
  end

  # 프리미엄 회원 여부 확인 (향후 구독 시스템 연동 예정)
  def premium?
    # TODO: 구독 시스템 연동 시 실제 구독 상태 확인 로직으로 변경
    false
  end

  # 지갑 잔액 조회
  def wallet_balance
    wallet&.balance || 0
  end

  # 모든 대화 가져오기
  def conversations
    Conversation.where("user_a_id = ? OR user_b_id = ?", id, id)
  end

  # 알림 생성 메서드
  def create_notification(type, body, title: nil, metadata: {}, notifiable: nil)
    notification = notifications.create!(
      notification_type: type,
      title: title,
      body: body,
      metadata: metadata,
      notifiable: notifiable
    )

    # 푸시 알림 전송 시도
    notification.send_push! if push_token.present? && push_enabled

    notification
  end

  # 읽지 않은 알림 수 조회
  def unread_notification_count
    notifications.unread.count
  end

  # 최근 인증 코드 찾기
  def latest_valid_verification
    phone_verifications.where(verified: false)
                      .where("expires_at > ?", Time.current)
                      .order(created_at: :desc)
                      .first
  end

  # 성별 검증 부분 수정 - 클라이언트 입력과 일치하도록
  validates :gender, inclusion: {
    in: %w[male female unspecified unknown other],
    message: "유효하지 않은 성별입니다. 허용값: male, female, unspecified, unknown, other"
  }, allow_nil: true, allow_blank: true

  # 테스트를 위한 JWT 토큰 생성 메서드
  def generate_token
    payload = {
      user_id: id,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
  end

  private

  # 사용자 생성 시 지갑 자동 생성
  def create_wallet_for_user
    create_wallet if wallet.nil?
  end

  # RailsAdmin 설정 (rails_admin gem이 활성화된 경우에만 사용)
  # rails_admin do
  #   list do
  #     field :id
  #     field :nickname
  #     field :phone
  #     field :gender
  #     field :created_at
  #     field :updated_at
  #     field :status
  #     field :report_count do
  #       formatted_value do
  #         bindings[:object].report_count
  #       end
  #       sortable false
  #     end
  #     field :push_enabled
  #   end
  #
  #   show do
  #     field :id
  #     field :nickname
  #     field :phone
  #     field :gender
  #     field :created_at
  #     field :updated_at
  #     field :status
  #     field :expo_push_token
  #     field :push_enabled
  #     field :broadcast_push_enabled
  #     field :message_push_enabled
  #     field :report_count do
  #       formatted_value do
  #         bindings[:object].report_count
  #       end
  #     end
  #     field :reports_as_reported
  #     field :broadcasts
  #   end
  #
  #   edit do
  #     field :nickname
  #     field :phone
  #     field :gender
  #     field :status
  #     field :expo_push_token
  #     field :push_enabled
  #     field :broadcast_push_enabled
  #     field :message_push_enabled
  #   end
  # end
end
