class CreateBroadcasts < ActiveRecord::Migration[7.0]
  def change
    create_table :broadcasts do |t|
      t.references :user, null: false, foreign_key: true
      t.text :content
      t.boolean :expired, default: false
      t.boolean :active, default: true
      t.datetime :expired_at
      
      t.timestamps
    end
  end
end
