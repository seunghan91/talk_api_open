# db/migrate/20250208050003_create_reports.rb
class CreateReports < ActiveRecord::Migration[7.0]
  def change
    create_table :reports do |t|
      t.bigint :reporter_id, null: false
      t.bigint :reported_id, null: false
      t.string :reason

      t.timestamps
    end

    add_foreign_key :reports, :users, column: :reporter_id
    add_foreign_key :reports, :users, column: :reported_id
  end
end