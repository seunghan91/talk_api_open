class CreateAnnouncements < ActiveRecord::Migration[7.0]
  def change
    create_table :announcements do |t|
      t.string :title
      t.text :content
      t.references :category, null: false, foreign_key: { to_table: :announcement_categories }
      t.boolean :is_important
      t.boolean :is_published
      t.boolean :is_hidden
      t.datetime :published_at

      t.timestamps
    end
  end
end
