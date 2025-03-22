class AddBroadcastColumnToConversations < ActiveRecord::Migration[7.0]
  def change
    add_reference :conversations, :broadcast, null: true, foreign_key: true, index: true
  end
end
