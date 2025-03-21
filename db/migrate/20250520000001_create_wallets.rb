class CreateWallets < ActiveRecord::Migration[7.0]
  def change
    create_table :wallets do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :balance, default: 0, precision: 10, scale: 2, null: false
      t.integer :transaction_count, default: 0, null: false

      t.timestamps
    end
    
    unless index_exists?(:wallets, :user_id)
      add_index :wallets, :user_id, unique: true
    end
  end
end 