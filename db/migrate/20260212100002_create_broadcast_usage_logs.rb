# frozen_string_literal: true

class CreateBroadcastUsageLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :broadcast_usage_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :broadcasts_sent, default: 0, null: false
      t.datetime :last_broadcast_at
      t.integer :limit_exceeded_count, default: 0, null: false

      t.timestamps
    end

    add_index :broadcast_usage_logs, [:user_id, :date], unique: true, name: "idx_broadcast_usage_user_date"
  end
end
