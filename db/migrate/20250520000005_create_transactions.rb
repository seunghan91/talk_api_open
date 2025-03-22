class CreateTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :transactions do |t|
      t.references :wallet, null: false, foreign_key: true
      t.string :transaction_type, null: false # 'deposit', 'withdrawal', 'purchase'
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :description
      t.string :payment_method
      t.string :status, default: 'completed', null: false # 'pending', 'completed', 'failed'
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    
    add_index :transactions, :transaction_type
    add_index :transactions, :status
    add_index :transactions, :created_at
  end
end 