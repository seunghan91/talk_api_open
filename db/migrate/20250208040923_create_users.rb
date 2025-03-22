class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :phone_number
      t.string :nickname
      t.string :gender
      t.string :unique_code
      t.boolean :is_verified, default: false
      t.boolean :terms_agreed, default: false
      t.boolean :blocked, default: false
      t.integer :point_balance, default: 0



      t.timestamps
    end
  end
end
