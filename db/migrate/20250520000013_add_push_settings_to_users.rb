class AddPushSettingsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :push_enabled, :boolean, default: true
    add_column :users, :broadcast_push_enabled, :boolean, default: true
    add_column :users, :message_push_enabled, :boolean, default: true
  end
end
