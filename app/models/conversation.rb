class Conversation < ApplicationRecord
    belongs_to :user_a, class_name: "User", foreign_key: :user_a_id
    belongs_to :user_b, class_name: "User", foreign_key: :user_b_id
    belongs_to :broadcast, optional: true

    has_many :messages, dependent: :destroy

    # 인덱스 활용을 위한 스코프 추가
    scope :between_users, ->(user1_id, user2_id) do
      where("(user_a_id = ? AND user_b_id = ?) OR (user_a_id = ? AND user_b_id = ?)",
            [ user1_id, user2_id ].min, [ user1_id, user2_id ].max,
            [ user1_id, user2_id ].max, [ user1_id, user2_id ].min)
    end

    scope :for_user, ->(user_id) do
      where("user_a_id = ? OR user_b_id = ?", user_id, user_id)
    end

    scope :not_deleted_for, ->(user_id) do
      where("(user_a_id = ? AND deleted_by_a = ?) OR (user_b_id = ? AND deleted_by_b = ?)",
            user_id, false, user_id, false)
    end

    scope :with_broadcast, ->(broadcast_id) do
      where(broadcast_id: broadcast_id)
    end

    # 대화가 즐겨찾기되었는지 확인
    def favorited_by?(user_id)
      if user_a_id == user_id
        favorited_by_a
      elsif user_b_id == user_id
        favorited_by_b
      else
        false
      end
    end

    # 특정 사용자에게 대화가 보이는지 확인
    def visible_to?(user_id)
      if user_a_id == user_id
        !deleted_by_a
      elsif user_b_id == user_id
        !deleted_by_b
      else
        false
      end
    end

    # 특정 사용자에게 대화를 보이게 설정
    def show_to!(user_id)
      if user_a_id == user_id
        update!(deleted_by_a: false)
      elsif user_b_id == user_id
        update!(deleted_by_b: false)
      end
    end

    # 특정 사용자에게 대화를 숨기기 설정
    def hide_from!(user_id)
      if user_a_id == user_id
        update!(deleted_by_a: true)
      elsif user_b_id == user_id
        update!(deleted_by_b: true)
      end
    end

    # 상대방 사용자 ID 반환
    def other_user_id(user_id)
      if user_a_id == user_id
        user_b_id
      elsif user_b_id == user_id
        user_a_id
      else
        nil
      end
    end

    # 사용자 정보를 올바르게 매핑하기 위한 메서드 추가
    def self.find_or_create_conversation(user1_id, user2_id, broadcast = nil)
      # 유효성 검사
      return nil if user1_id == user2_id

      # 항상 작은 ID를 user_a_id로, 큰 ID를 user_b_id로 저장
      user_a_id = [ user1_id, user2_id ].min
      user_b_id = [ user1_id, user2_id ].max

      conversation = between_users(user_a_id, user_b_id).first

      # 대화가 존재하지 않으면 새로 생성
      unless conversation
        conversation = create!(
          user_a_id: user_a_id,
          user_b_id: user_b_id,
          broadcast_id: broadcast&.id,
          # 기본 상태는 양쪽 모두 보이도록 설정
          deleted_by_a: false,
          deleted_by_b: false
        )

        # 브로드캐스트가 있을 경우 첫 메시지로 추가
        if broadcast.present?
          conversation.messages.create!(
            sender_id: broadcast.user_id,
            broadcast_id: broadcast.id,
            message_type: "broadcast"
          )
        end
      end

      # 삭제 플래그 초기화: 요청한 사용자에게 대화가 보이도록 설정
      conversation.show_to!(user1_id)

      conversation
    end

    # 브로드캐스트로부터 대화 생성
    def self.create_from_broadcast(broadcast, recipient_id)
      # 브로드캐스트 발신자와 수신자 ID 확인
      sender_id = broadcast.user_id

      # 대화 찾기 또는 생성
      conversation = find_or_create_conversation(sender_id, recipient_id, broadcast)

      # 대화 생성에 실패한 경우
      unless conversation&.persisted?
        Rails.logger.error("브로드캐스트에서 대화 생성 실패: 브로드캐스트 ID #{broadcast.id}, 수신자 ID #{recipient_id}")
        return nil
      end

    # 브로드캐스트 수신자는 처음에는 대화방이 보이지 않도록 설정
    # (답장하기 전까지 보이지 않음)
    conversation.hide_from!(recipient_id)

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
