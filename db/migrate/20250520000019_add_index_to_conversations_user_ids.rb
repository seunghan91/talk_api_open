class AddIndexToConversationsUserIds < ActiveRecord::Migration[7.0]
  def change
    # 대화방 중복 방지 및 효율적인 조회를 위한 복합 인덱스 추가
    add_index :conversations, [ :user_a_id, :user_b_id ], unique: true,
              name: 'index_conversations_on_user_a_id_and_user_b_id'

    # 사용자별 대화방 조회 속도 향상을 위한 인덱스
    # 이미 존재하는 인덱스지만 누락되었을 경우를 대비해 추가 (명시적으로 존재하면 무시됨)
    add_index :conversations, :user_a_id unless index_exists?(:conversations, :user_a_id)
    add_index :conversations, :user_b_id unless index_exists?(:conversations, :user_b_id)

    # 브로드캐스트별 대화방 조회 효율화
    add_index :conversations, :broadcast_id unless index_exists?(:conversations, :broadcast_id)
  end
end
