class CreateBroadcasts < ActiveRecord::Migration[7.0]
  def change
    create_table :broadcasts do |t|
      t.references :user, null: false, foreign_key: true
      t.text :content
      t.datetime :expired_at

      t.timestamps
    end
  end
end
