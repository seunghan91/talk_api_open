class AddActiveToBroadcasts < ActiveRecord::Migration[7.0]
  def change
    add_column :broadcasts, :active, :boolean, default: true
  end
end 