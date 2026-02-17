# frozen_string_literal: true

class AddAuditColumnsToBroadcasts < ActiveRecord::Migration[8.1]
  def change
    add_column :broadcasts, :ip_address, :string, limit: 45
    add_column :broadcasts, :user_agent, :text

    # 일일 제한 체크 최적화용 복합 인덱스
    add_index :broadcasts, [:user_id, :created_at], name: "idx_broadcasts_sender_date"
  end
end
