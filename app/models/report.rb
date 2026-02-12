# app/models/report.rb
class Report < ApplicationRecord
    belongs_to :reporter, class_name: "User", foreign_key: :reporter_id
    belongs_to :reported, class_name: "User", foreign_key: :reported_id

    enum :status, { pending: 0, processing: 1, resolved: 2, rejected: 3 }, prefix: true, validate: true
    enum :report_type, { user: 0, broadcast: 1, message: 2, feedback: 3 }, prefix: true, validate: true

    validates :reason, presence: true

    # 관련 브로드캐스트 또는 메시지 ID 저장을 위한 속성
    attribute :related_id, :integer

  # RailsAdmin 설정 (rails_admin gem이 활성화된 경우에만 사용)
  # rails_admin do
  #   list do
  #     field :id
  #     field :reporter
  #     field :reported
  #     field :reason
  #     field :status
  #     field :report_type
  #     field :related_id
  #     field :created_at
  #     field :updated_at
  #   end
  #
  #   show do
  #     field :id
  #     field :reporter
  #     field :reported
  #     field :reason
  #     field :status
  #     field :report_type
  #     field :related_id
  #     field :created_at
  #     field :updated_at
  #   end
  #
  #   edit do
  #     field :reporter
  #     field :reported
  #     field :reason
  #     field :status
  #     field :report_type
  #     field :related_id
  #   end
  # end
end
