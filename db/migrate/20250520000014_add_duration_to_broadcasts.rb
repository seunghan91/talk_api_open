class AddDurationToBroadcasts < ActiveRecord::Migration[7.0]
  def change
    add_column :broadcasts, :duration, :integer, default: 0, null: false
  end
end
