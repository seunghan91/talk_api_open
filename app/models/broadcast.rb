# app/models/broadcast.rb
class Broadcast < ApplicationRecord
    belongs_to :user
  
    # 음성 파일 첨부
    has_one_attached :voice_file
  
    before_create :set_expired_at
  
    # 만료 여부 확인
    def expired?
      expired_at < Time.current
    end
  
    # 만료 예정 확인 (24시간 이내)
    def expiring_soon?
      !expired? && expired_at < 24.hours.from_now
    end
  
    # 활성화 상태 확인
    def active?
      active && !expired?
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
      self.expired_at = 24.hours.from_now
    end
  end