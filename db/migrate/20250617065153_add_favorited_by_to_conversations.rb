class AddFavoritedByToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :favorited_by_a, :boolean, default: false
    add_column :conversations, :favorited_by_b, :boolean, default: false
  end
end
