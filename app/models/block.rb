# app/models/block.rb
class Block < ApplicationRecord
    belongs_to :blocker, class_name: 'User', foreign_key: :blocker_id
    belongs_to :blocked, class_name: 'User', foreign_key: :blocked_id
    
    # RailsAdmin 설정 (rails_admin gem이 활성화된 경우에만 사용)
    # rails_admin do
    #   list do
    #     field :id
    #     field :blocker
    #     field :blocked
    #     field :created_at
    #   end
    #   
    #   show do
    #     field :id
    #     field :blocker
    #     field :blocked
    #     field :created_at
    #     field :updated_at
    #   end
    # end
  end