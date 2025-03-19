class CreatePhoneVerifications < ActiveRecord::Migration[7.0]
  def change
    create_table :phone_verifications do |t|
      t.string :phone_number
      t.string :code
      t.datetime :expires_at
      t.boolean :verified, default: false

      t.timestamps
    end
  end
end