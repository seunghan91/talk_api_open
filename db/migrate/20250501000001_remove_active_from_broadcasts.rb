class RemoveActiveFromBroadcasts < ActiveRecord::Migration[7.0]
  def change
    # 컬럼이 존재할 경우에만 제거
    if column_exists?(:broadcasts, :active)
      remove_column :broadcasts, :active, :boolean
    end
  end
end 