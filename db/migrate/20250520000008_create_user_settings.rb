class CreateUserSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :user_settings do |t|
      t.references :user, null: false, foreign_key: true
      t.boolean :notification_enabled
      t.boolean :sound_enabled
      t.boolean :vibration_enabled
      t.string :theme
      t.string :language

      t.timestamps
    end
  end
end
