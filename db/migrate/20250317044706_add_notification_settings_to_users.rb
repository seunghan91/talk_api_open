class AddNotificationSettingsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :receive_new_letter, :boolean, default: true
    add_column :users, :letter_receive_alarm, :boolean, default: true
  end
end
