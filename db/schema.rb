# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_06_17_065153) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "announcement_categories", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "announcements", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.bigint "category_id", null: false
    t.boolean "is_important"
    t.boolean "is_published"
    t.boolean "is_hidden"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_announcements_on_category_id"
  end

  create_table "blocks", force: :cascade do |t|
    t.bigint "blocker_id", null: false
    t.bigint "blocked_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "broadcast_recipients", force: :cascade do |t|
    t.bigint "broadcast_id", null: false
    t.bigint "user_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["broadcast_id", "user_id"], name: "index_broadcast_recipients_on_broadcast_id_and_user_id", unique: true
    t.index ["broadcast_id"], name: "index_broadcast_recipients_on_broadcast_id"
    t.index ["status"], name: "index_broadcast_recipients_on_status"
    t.index ["user_id"], name: "index_broadcast_recipients_on_user_id"
  end

  create_table "broadcasts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content"
    t.datetime "expired_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true
    t.integer "duration", default: 0, null: false
    t.index ["user_id"], name: "index_broadcasts_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "user_a_id", null: false
    t.bigint "user_b_id", null: false
    t.boolean "active", default: true
    t.boolean "favorite", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "broadcast_id"
    t.boolean "deleted_by_a", default: false
    t.boolean "deleted_by_b", default: false
    t.boolean "favorited_by_a", default: false
    t.boolean "favorited_by_b", default: false
    t.index ["broadcast_id"], name: "index_conversations_on_broadcast_id"
    t.index ["user_a_id", "user_b_id"], name: "index_conversations_on_user_a_id_and_user_b_id", unique: true
    t.index ["user_a_id"], name: "index_conversations_on_user_a_id"
    t.index ["user_b_id"], name: "index_conversations_on_user_b_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "sender_id", null: false
    t.boolean "read", default: false
    t.string "message_type", default: "voice"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "broadcast_id"
    t.integer "duration", default: 0, null: false
    t.boolean "deleted_by_a", default: false, null: false
    t.boolean "deleted_by_b", default: false, null: false
    t.index ["broadcast_id"], name: "index_messages_on_broadcast_id"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notification_type", null: false
    t.string "title"
    t.text "body", null: false
    t.jsonb "metadata", default: {}
    t.boolean "read", default: false
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["read"], name: "index_notifications_on_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "payment_products", force: :cascade do |t|
    t.string "product_id", null: false
    t.string "name", null: false
    t.integer "amount", null: false
    t.integer "bonus_amount", default: 0
    t.integer "price", null: false
    t.boolean "active", default: true
    t.integer "sort_order", default: 0
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_payment_products_on_active"
    t.index ["product_id"], name: "index_payment_products_on_product_id", unique: true
    t.index ["sort_order"], name: "index_payment_products_on_sort_order"
  end

  create_table "phone_verifications", force: :cascade do |t|
    t.string "phone_number"
    t.string "code"
    t.datetime "expires_at"
    t.boolean "verified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.integer "attempt_count", default: 0, null: false
    t.index ["user_id"], name: "index_phone_verifications_on_user_id"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "reporter_id", null: false
    t.bigint "reported_id", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0, null: false
    t.integer "report_type", default: 0, null: false
    t.integer "related_id"
    t.index ["report_type"], name: "index_reports_on_report_type"
    t.index ["status"], name: "index_reports_on_status"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "wallet_id", null: false
    t.string "transaction_type", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "description"
    t.string "payment_method"
    t.string "status", default: "completed", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_transactions_on_created_at"
    t.index ["status"], name: "index_transactions_on_status"
    t.index ["transaction_type"], name: "index_transactions_on_transaction_type"
    t.index ["wallet_id"], name: "index_transactions_on_wallet_id"
  end

  create_table "user_settings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.boolean "notification_enabled"
    t.boolean "sound_enabled"
    t.boolean "vibration_enabled"
    t.string "theme"
    t.string "language"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_settings_on_user_id"
  end

  create_table "user_suspensions", force: :cascade do |t|
    t.bigint "user_id", null: false, comment: "정지된 사용자 외래키"
    t.string "reason", comment: "정지 사유"
    t.datetime "suspended_at", comment: "정지 시작 시간"
    t.datetime "suspended_until", comment: "정지 만료 시간"
    t.string "suspended_by", default: "system", comment: "정지 집행자 (시스템/관리자)"
    t.boolean "active", default: true, comment: "현재 활성 정지 여부"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "suspended_until"], name: "index_user_suspensions_on_active_and_until"
    t.index ["user_id"], name: "index_user_suspensions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "phone_number"
    t.string "nickname"
    t.string "gender"
    t.string "unique_code"
    t.boolean "is_verified", default: false
    t.boolean "terms_agreed", default: false
    t.boolean "blocked", default: false
    t.integer "point_balance", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified"
    t.string "push_token"
    t.string "password_digest"
    t.boolean "receive_new_letter", default: true
    t.boolean "letter_receive_alarm", default: true
    t.string "phone"
    t.string "phone_bidx"
    t.datetime "last_login_at"
    t.boolean "push_enabled", default: true
    t.boolean "broadcast_push_enabled", default: true
    t.boolean "message_push_enabled", default: true
    t.string "age_group", comment: "사용자 연령대: 20s, 30s, 40s, 50s"
    t.string "region", comment: "사용자 지역: 국가/시도 형식"
    t.boolean "profile_completed", default: false
    t.integer "warning_count", default: 0, comment: "사용자 경고 누적 횟수"
    t.index ["gender", "age_group"], name: "index_users_on_gender_and_age"
    t.index ["phone_bidx"], name: "index_users_on_phone_bidx", unique: true
    t.index ["push_token"], name: "index_users_on_push_token"
    t.index ["region"], name: "index_users_on_region"
  end

  create_table "wallets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "balance", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "transaction_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_wallets_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "announcements", "announcement_categories", column: "category_id"
  add_foreign_key "blocks", "users", column: "blocked_id"
  add_foreign_key "blocks", "users", column: "blocker_id"
  add_foreign_key "broadcast_recipients", "broadcasts"
  add_foreign_key "broadcast_recipients", "users"
  add_foreign_key "broadcasts", "users"
  add_foreign_key "conversations", "broadcasts"
  add_foreign_key "conversations", "users", column: "user_a_id"
  add_foreign_key "conversations", "users", column: "user_b_id"
  add_foreign_key "messages", "broadcasts"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "phone_verifications", "users"
  add_foreign_key "reports", "users", column: "reported_id"
  add_foreign_key "reports", "users", column: "reporter_id"
  add_foreign_key "transactions", "wallets"
  add_foreign_key "user_settings", "users"
  add_foreign_key "user_suspensions", "users"
  add_foreign_key "wallets", "users"
end
