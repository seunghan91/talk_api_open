class CreateConversations < ActiveRecord::Migration[7.0]
  def change
    create_table :conversations do |t|
      t.references :user1, null: false, foreign_key: { to_table: :users }
      t.references :user2, null: false, foreign_key: { to_table: :users }
      t.boolean :user1_active, default: true
      t.boolean :user2_active, default: true
      t.datetime :last_message_at
      t.boolean :is_blocked, default: false
      
      t.timestamps
    end
  end
end
