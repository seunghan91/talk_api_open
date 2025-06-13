class AddStatusAndTypeToReports < ActiveRecord::Migration[7.0]
  def change
    add_column :reports, :status, :integer, default: 0, null: false
    add_column :reports, :report_type, :integer, default: 0, null: false
    add_column :reports, :related_id, :integer

    add_index :reports, :status
    add_index :reports, :report_type
  end
end
