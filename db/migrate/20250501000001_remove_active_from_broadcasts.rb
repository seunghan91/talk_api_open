class RemoveActiveFromBroadcasts < ActiveRecord::Migration[7.0]
  def change
    remove_column :broadcasts, :active, :boolean
  end
end 