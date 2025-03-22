class AddUserIdToPhoneVerifications < ActiveRecord::Migration[7.0]
  def change
    add_reference :phone_verifications, :user, null: true, foreign_key: true, index: true
  end
end
