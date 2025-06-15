class CreatePaymentProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_products do |t|
      t.string :product_id, null: false # 인앱 결제 상품 ID
      t.string :name, null: false
      t.integer :amount, null: false # 기본 캐시
      t.integer :bonus_amount, default: 0 # 보너스 캐시
      t.integer :price, null: false # 실제 결제 금액 (원)
      t.boolean :active, default: true
      t.integer :sort_order, default: 0
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :payment_products, :product_id, unique: true
    add_index :payment_products, :active
    add_index :payment_products, :sort_order
  end
end 