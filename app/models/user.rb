# app/models/user.rb
class User < ApplicationRecord
  # 비밀번호 암호화 및 인증 기능
  has_secure_password validations: false
  
  encrypts :phone  # Rails 7 AR 암호화

  # status 필드를 attribute로 선언
  attribute :status, :integer, default: 0
  attribute :gender, :integer, default: 1
  
  enum :gender, { unknown: 0, male: 1, female: 2 }, prefix: true
  enum :status, { active: 0, suspended: 1, banned: 2 }, prefix: true
  
  has_many :broadcasts, dependent: :destroy
  has_many :reports_as_reporter, class_name: 'Report', foreign_key: :reporter_id
  has_many :reports_as_reported, class_name: 'Report', foreign_key: :reported_id
  has_many :blocks_as_blocker, class_name: 'Block', foreign_key: :blocker_id
  has_many :blocks_as_blocked, class_name: 'Block', foreign_key: :blocked_id
  
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

  # 신고 횟수 카운트 메서드
  def report_count
    reports_as_reported.count
  end
  
  # 차단 여부 확인 메서드
  def blocked?
    status_banned? || status_suspended?
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