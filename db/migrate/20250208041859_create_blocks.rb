# db/migrate/20250208050004_create_blocks.rb
class CreateBlocks < ActiveRecord::Migration[7.0]
  def change
    create_table :blocks do |t|
      t.bigint :blocker_id, null: false
      t.bigint :blocked_id, null: false

      t.timestamps
    end

    add_foreign_key :blocks, :users, column: :blocker_id
    add_foreign_key :blocks, :users, column: :blocked_id
  end
end