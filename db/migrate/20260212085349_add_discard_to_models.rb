class AddDiscardToModels < ActiveRecord::Migration[8.1]
  def change
    add_column :broadcasts, :discarded_at, :datetime
    add_column :messages, :discarded_at, :datetime
    add_column :conversations, :discarded_at, :datetime
    add_index :broadcasts, :discarded_at
    add_index :messages, :discarded_at
    add_index :conversations, :discarded_at
  end
end
