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

ActiveRecord::Schema[8.1].define(version: 2026_02_19_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "announcement_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "announcements", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.boolean "is_hidden"
    t.boolean "is_important"
    t.boolean "is_published"
    t.datetime "published_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_announcements_on_category_id"
  end

  create_table "blocks", force: :cascade do |t|
    t.bigint "blocked_id", null: false
    t.bigint "blocker_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "broadcast_recipients", force: :cascade do |t|
    t.bigint "broadcast_id", null: false
    t.datetime "created_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["broadcast_id", "user_id"], name: "index_broadcast_recipients_on_broadcast_id_and_user_id", unique: true
    t.index ["broadcast_id"], name: "index_broadcast_recipients_on_broadcast_id"
    t.index ["status"], name: "index_broadcast_recipients_on_status"
    t.index ["user_id"], name: "index_broadcast_recipients_on_user_id"
  end

  create_table "broadcast_usage_logs", force: :cascade do |t|
    t.integer "broadcasts_sent", default: 0, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.datetime "last_broadcast_at"
    t.integer "limit_exceeded_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "date"], name: "idx_broadcast_usage_user_date", unique: true
    t.index ["user_id"], name: "index_broadcast_usage_logs_on_user_id"
  end

  create_table "broadcasts", force: :cascade do |t|
    t.boolean "active", default: true
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.integer "duration", default: 0, null: false
    t.datetime "expired_at"
    t.string "ip_address", limit: 45
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.bigint "user_id", null: false
    t.index ["discarded_at"], name: "index_broadcasts_on_discarded_at"
    t.index ["user_id", "created_at"], name: "idx_broadcasts_sender_date"
    t.index ["user_id"], name: "index_broadcasts_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.boolean "active", default: true
    t.bigint "broadcast_id"
    t.datetime "created_at", null: false
    t.boolean "deleted_by_a", default: false
    t.boolean "deleted_by_b", default: false
    t.datetime "discarded_at"
    t.boolean "favorite", default: false
    t.boolean "favorited_by_a", default: false
    t.boolean "favorited_by_b", default: false
    t.datetime "last_read_at_a"
    t.datetime "last_read_at_b"
    t.datetime "updated_at", null: false
    t.bigint "user_a_id", null: false
    t.bigint "user_b_id", null: false
    t.index ["broadcast_id"], name: "index_conversations_on_broadcast_id"
    t.index ["discarded_at"], name: "index_conversations_on_discarded_at"
    t.index ["user_a_id", "user_b_id"], name: "index_conversations_on_user_a_id_and_user_b_id", unique: true
    t.index ["user_a_id"], name: "index_conversations_on_user_a_id"
    t.index ["user_b_id"], name: "index_conversations_on_user_b_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "broadcast_id"
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.boolean "deleted_by_a", default: false, null: false
    t.boolean "deleted_by_b", default: false, null: false
    t.datetime "discarded_at"
    t.integer "duration", default: 0, null: false
    t.string "message_type", default: "voice"
    t.boolean "read", default: false
    t.bigint "sender_id", null: false
    t.datetime "updated_at", null: false
    t.index ["broadcast_id"], name: "index_messages_on_broadcast_id"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["discarded_at"], name: "index_messages_on_discarded_at"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.bigint "notifiable_id"
    t.string "notifiable_type"
    t.string "notification_type", null: false
    t.boolean "read", default: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["read"], name: "index_notifications_on_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "payment_products", force: :cascade do |t|
    t.boolean "active", default: true
    t.integer "amount", null: false
    t.integer "bonus_amount", default: 0
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.integer "price", null: false
    t.string "product_id", null: false
    t.integer "sort_order", default: 0
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_payment_products_on_active"
    t.index ["product_id"], name: "index_payment_products_on_product_id", unique: true
    t.index ["sort_order"], name: "index_payment_products_on_sort_order"
  end

  create_table "phone_verifications", force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "phone_number"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.boolean "verified", default: false
    t.index ["user_id"], name: "index_phone_verifications_on_user_id"
  end

  create_table "reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "reason"
    t.integer "related_id"
    t.integer "report_type", default: 0, null: false
    t.bigint "reported_id", null: false
    t.bigint "reporter_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["report_type"], name: "index_reports_on_report_type"
    t.index ["status"], name: "index_reports_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_active_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "system_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_active", default: true
    t.string "setting_key", null: false
    t.jsonb "setting_value", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "updated_by_id"
    t.index ["setting_key"], name: "index_system_settings_on_setting_key", unique: true
    t.index ["updated_by_id"], name: "index_system_settings_on_updated_by_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.jsonb "metadata", default: {}
    t.string "payment_method"
    t.string "status", default: "completed", null: false
    t.string "transaction_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "wallet_id", null: false
    t.index ["created_at"], name: "index_transactions_on_created_at"
    t.index ["status"], name: "index_transactions_on_status"
    t.index ["transaction_type"], name: "index_transactions_on_transaction_type"
    t.index ["wallet_id"], name: "index_transactions_on_wallet_id"
  end

  create_table "user_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "language"
    t.boolean "notification_enabled"
    t.boolean "sound_enabled"
    t.string "theme"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.boolean "vibration_enabled"
    t.index ["user_id"], name: "index_user_settings_on_user_id"
  end

  create_table "user_suspensions", force: :cascade do |t|
    t.boolean "active", default: true, comment: "현재 활성 정지 여부"
    t.datetime "created_at", null: false
    t.string "reason", comment: "정지 사유"
    t.datetime "suspended_at", comment: "정지 시작 시간"
    t.string "suspended_by", default: "system", comment: "정지 집행자 (시스템/관리자)"
    t.datetime "suspended_until", comment: "정지 만료 시간"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false, comment: "정지된 사용자 외래키"
    t.index ["active", "suspended_until"], name: "index_user_suspensions_on_active_and_until"
    t.index ["user_id"], name: "index_user_suspensions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "age_group", comment: "사용자 연령대: 20s, 30s, 40s, 50s"
    t.boolean "blocked", default: false
    t.boolean "broadcast_push_enabled", default: true
    t.datetime "created_at", null: false
    t.string "gender"
    t.boolean "is_admin", default: false, null: false
    t.boolean "is_verified", default: false
    t.datetime "last_login_at"
    t.boolean "letter_receive_alarm", default: true
    t.boolean "message_push_enabled", default: true
    t.string "nickname"
    t.string "password_digest"
    t.string "phone"
    t.string "phone_bidx"
    t.string "phone_number"
    t.integer "point_balance", default: 0
    t.boolean "profile_completed", default: false
    t.boolean "push_enabled", default: true
    t.string "push_token"
    t.boolean "receive_new_letter", default: true
    t.string "region", comment: "사용자 지역: 국가/시도 형식"
    t.boolean "terms_agreed", default: false
    t.string "unique_code"
    t.datetime "updated_at", null: false
    t.boolean "verified"
    t.integer "warning_count", default: 0, comment: "사용자 경고 누적 횟수"
    t.index ["gender", "age_group"], name: "index_users_on_gender_and_age"
    t.index ["phone_bidx"], name: "index_users_on_phone_bidx", unique: true
    t.index ["push_token"], name: "index_users_on_push_token"
    t.index ["region"], name: "index_users_on_region"
  end

  create_table "wallets", force: :cascade do |t|
    t.decimal "balance", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.integer "transaction_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_wallets_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "announcements", "announcement_categories", column: "category_id"
  add_foreign_key "blocks", "users", column: "blocked_id"
  add_foreign_key "blocks", "users", column: "blocker_id"
  add_foreign_key "broadcast_recipients", "broadcasts"
  add_foreign_key "broadcast_recipients", "users"
  add_foreign_key "broadcast_usage_logs", "users"
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
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "system_settings", "users", column: "updated_by_id"
  add_foreign_key "transactions", "wallets"
  add_foreign_key "user_settings", "users"
  add_foreign_key "user_suspensions", "users"
  add_foreign_key "wallets", "users"
end
