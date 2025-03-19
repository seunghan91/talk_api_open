class CreateMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      # sender -> users.id
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.boolean :read, default: false
      t.text :content, null: true
      t.string :message_type, default: "voice"

      t.timestamps
    end
  end
end
