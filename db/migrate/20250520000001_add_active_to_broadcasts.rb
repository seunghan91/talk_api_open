class AddActiveToBroadcasts < ActiveRecord::Migration[6.1]
  def change
    add_column :broadcasts, :active, :boolean, default: true
  end
end 