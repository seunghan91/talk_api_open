class CreateSolidCacheEntries < ActiveRecord::Migration[8.1]
  def change
    return if connection.table_exists?("solid_cache_entries")

    create_table "solid_cache_entries" do |t|
      t.binary "key", null: false
      t.binary "value", null: false
      t.datetime "created_at", null: false
      t.bigint "key_hash", null: false
      t.integer "byte_size", null: false
    end
    add_index "solid_cache_entries", ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    add_index "solid_cache_entries", ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    add_index "solid_cache_entries", ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end
end
