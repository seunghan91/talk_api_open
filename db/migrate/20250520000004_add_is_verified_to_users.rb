class AddIsVerifiedToUsers < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:users, :is_verified)
      add_column :users, :is_verified, :boolean, default: false
    end
  end
end
