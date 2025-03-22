class CreateNotifications < ActiveRecord::Migration[7.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :notification_type, null: false # 'message', 'broadcast', 'system'
      t.string :title
      t.text :body, null: false
      t.jsonb :metadata, default: {}
      t.boolean :read, default: false
      t.references :notifiable, polymorphic: true

      t.timestamps
    end

    add_index :notifications, :notification_type
    add_index :notifications, :read
    add_index :notifications, :created_at
  end
end
