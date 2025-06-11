class AddBroadcastIdToMessages < ActiveRecord::Migration[7.0]
  def change
    add_reference :messages, :broadcast, null: true, foreign_key: true, index: true

    # 스키마 확인 후 message_type 필드가 없는 경우에만 추가
    # 단, 기존 스키마와 마이그레이션 파일 간 불일치가 있는 것으로 보임
    unless column_exists?(:messages, :message_type)
      add_column :messages, :message_type, :string, default: "voice", null: false
      add_index :messages, :message_type unless index_exists?(:messages, :message_type)
    end

    # content 필드가 있지만 스키마에 없는 경우 제거
    if column_exists?(:messages, :content)
      remove_column :messages, :content
    end
  end
end
