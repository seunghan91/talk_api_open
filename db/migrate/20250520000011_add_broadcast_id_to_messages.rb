class AddBroadcastIdToMessages < ActiveRecord::Migration[7.0]
  def change
    add_reference :messages, :broadcast, null: true, foreign_key: true, index: true
    
    # message_type 필드 추가 (일반 메시지와 브로드캐스트 메시지 구분)
    add_column :messages, :message_type, :string, default: "voice", null: false
    add_index :messages, :message_type
  end
end
