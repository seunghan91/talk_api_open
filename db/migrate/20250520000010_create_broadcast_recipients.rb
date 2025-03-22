class CreateBroadcastRecipients < ActiveRecord::Migration[7.0]
  def change
    create_table :broadcast_recipients do |t|
      t.references :broadcast, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    # 같은 broadcast에 대한 동일 user의 중복 수신 방지
    add_index :broadcast_recipients, [:broadcast_id, :user_id], unique: true
    
    # status 기반 검색 인덱스 추가
    add_index :broadcast_recipients, :status
  end
end
