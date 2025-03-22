class AddPhoneEncryptedToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :phone, :string
    add_column :users, :phone_bidx, :string
    add_index :users, :phone_bidx, unique: true
  end
end 