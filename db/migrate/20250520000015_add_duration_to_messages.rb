class AddDurationToMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :messages, :duration, :integer, default: 0, null: false
  end
end
