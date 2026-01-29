class AddLastReadAtToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :last_read_at_a, :datetime
    add_column :conversations, :last_read_at_b, :datetime
  end
end
