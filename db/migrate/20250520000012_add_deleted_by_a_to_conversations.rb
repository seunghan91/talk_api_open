class AddDeletedByAToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :deleted_by_a, :boolean, default: false
    add_column :conversations, :deleted_by_b, :boolean, default: false
  end
end
