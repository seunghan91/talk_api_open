class Conversation < ApplicationRecord
    belongs_to :user_a, class_name: 'User', foreign_key: :user_a_id
    belongs_to :user_b, class_name: 'User', foreign_key: :user_b_id
  
    has_many :messages, dependent: :destroy
    
    # 사용자 정보를 올바르게 매핑하기 위한 메서드 추가
    def self.find_or_create_conversation(user1_id, user2_id)
      # 항상 작은 ID를 user_a_id로, 큰 ID를 user_b_id로 저장
      user_a_id = [user1_id, user2_id].min
      user_b_id = [user1_id, user2_id].max
      
      conversation = Conversation.find_by(user_a_id: user_a_id, user_b_id: user_b_id)
      
      # 대화가 존재하지 않으면 새로 생성
      unless conversation
        conversation = Conversation.create!(user_a_id: user_a_id, user_b_id: user_b_id)
      end
      
      conversation
    end
    
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