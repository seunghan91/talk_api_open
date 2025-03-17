class Conversation < ApplicationRecord
    belongs_to :user_a, class_name: 'User', foreign_key: :user_a_id
    belongs_to :user_b, class_name: 'User', foreign_key: :user_b_id
  
    has_many :messages, dependent: :destroy
    
    # RailsAdmin 설정 (rails_admin gem이 활성화된 경우에만 사용)
    # rails_admin do
    #   list do
    #     field :id
    #     field :user_a
    #     field :user_b
    #     field :created_at
    #     field :updated_at
    #     field :messages do
    #       formatted_value do
    #         bindings[:object].messages.count
    #       end
    #       sortable false
    #     end
    #   end
    #   
    #   show do
    #     field :id
    #     field :user_a
    #     field :user_b
    #     field :created_at
    #     field :updated_at
    #     field :messages
    #   end
    # end
  end