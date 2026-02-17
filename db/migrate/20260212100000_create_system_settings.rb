# frozen_string_literal: true

class CreateSystemSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :system_settings do |t|
      t.string :setting_key, null: false
      t.jsonb :setting_value, null: false, default: {}
      t.text :description
      t.boolean :is_active, default: true
      t.references :updated_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :system_settings, :setting_key, unique: true

    # 브로드캐스트 제한 설정 초기값 삽입
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO system_settings (setting_key, setting_value, description, is_active, created_at, updated_at)
          VALUES (
            'broadcast_limits',
            '{"daily_limit": 20, "hourly_limit": 5, "cooldown_minutes": 10, "bypass_roles": ["admin"]}'::jsonb,
            'Broadcast rate limiting configuration',
            true,
            NOW(),
            NOW()
          );
        SQL
      end
    end
  end
end
