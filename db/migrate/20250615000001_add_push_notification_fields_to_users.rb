class AddPushNotificationFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :push_token, :string unless column_exists?(:users, :push_token)
    add_column :users, :push_enabled, :boolean, default: true unless column_exists?(:users, :push_enabled)
    add_column :users, :message_push_enabled, :boolean, default: true unless column_exists?(:users, :message_push_enabled)
    add_column :users, :broadcast_push_enabled, :boolean, default: true unless column_exists?(:users, :broadcast_push_enabled)
    
    add_index :users, :push_token unless index_exists?(:users, :push_token)
  end
end 