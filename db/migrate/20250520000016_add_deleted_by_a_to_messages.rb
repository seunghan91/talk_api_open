class AddDeletedByAToMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :messages, :deleted_by_a, :boolean, default: false, null: false
    add_column :messages, :deleted_by_b, :boolean, default: false, null: false
  end
end
