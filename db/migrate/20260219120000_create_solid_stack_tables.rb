class CreateSolidStackTables < ActiveRecord::Migration[8.1]
  def change
    # ===== Solid Queue =====
    unless table_exists?(:solid_queue_jobs)
      create_table :solid_queue_jobs do |t|
        t.string :queue_name, null: false
        t.string :class_name, null: false
        t.text :arguments
        t.integer :priority, default: 0, null: false
        t.string :active_job_id
        t.datetime :scheduled_at
        t.datetime :finished_at
        t.string :concurrency_key
        t.timestamps null: false
      end
      add_index :solid_queue_jobs, :active_job_id
      add_index :solid_queue_jobs, :class_name
      add_index :solid_queue_jobs, :finished_at
      add_index :solid_queue_jobs, [:queue_name, :finished_at], name: "index_solid_queue_jobs_for_filtering"
      add_index :solid_queue_jobs, [:scheduled_at, :finished_at], name: "index_solid_queue_jobs_for_alerting"
    end

    unless table_exists?(:solid_queue_blocked_executions)
      create_table :solid_queue_blocked_executions do |t|
        t.bigint :job_id, null: false
        t.string :queue_name, null: false
        t.integer :priority, default: 0, null: false
        t.string :concurrency_key, null: false
        t.datetime :expires_at, null: false
        t.datetime :created_at, null: false
      end
      add_index :solid_queue_blocked_executions, [:concurrency_key, :priority, :job_id], name: "index_solid_queue_blocked_executions_for_release"
      add_index :solid_queue_blocked_executions, [:expires_at, :concurrency_key], name: "index_solid_queue_blocked_executions_for_maintenance"
      add_index :solid_queue_blocked_executions, :job_id, unique: true
      add_foreign_key :solid_queue_blocked_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    end

    unless table_exists?(:solid_queue_claimed_executions)
      create_table :solid_queue_claimed_executions do |t|
        t.bigint :job_id, null: false
        t.bigint :process_id
        t.datetime :created_at, null: false
      end
      add_index :solid_queue_claimed_executions, :job_id, unique: true
      add_index :solid_queue_claimed_executions, [:process_id, :job_id]
      add_foreign_key :solid_queue_claimed_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    end

    unless table_exists?(:solid_queue_failed_executions)
      create_table :solid_queue_failed_executions do |t|
        t.bigint :job_id, null: false
        t.text :error
        t.datetime :created_at, null: false
      end
      add_index :solid_queue_failed_executions, :job_id, unique: true
      add_foreign_key :solid_queue_failed_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    end

    unless table_exists?(:solid_queue_pauses)
      create_table :solid_queue_pauses do |t|
        t.string :queue_name, null: false
        t.datetime :created_at, null: false
      end
      add_index :solid_queue_pauses, :queue_name, unique: true
    end

    unless table_exists?(:solid_queue_processes)
      create_table :solid_queue_processes do |t|
        t.string :kind, null: false
        t.datetime :last_heartbeat_at, null: false
        t.bigint :supervisor_id
        t.integer :pid, null: false
        t.string :hostname
        t.text :metadata
        t.datetime :created_at, null: false
        t.string :name, null: false
      end
      add_index :solid_queue_processes, :last_heartbeat_at
      add_index :solid_queue_processes, [:name, :supervisor_id], unique: true
      add_index :solid_queue_processes, :supervisor_id
    end

    unless table_exists?(:solid_queue_ready_executions)
      create_table :solid_queue_ready_executions do |t|
        t.bigint :job_id, null: false
        t.string :queue_name, null: false
        t.integer :priority, default: 0, null: false
        t.datetime :created_at, null: false
      end
      add_index :solid_queue_ready_executions, :job_id, unique: true
      add_index :solid_queue_ready_executions, [:priority, :job_id], name: "index_solid_queue_poll_all"
      add_index :solid_queue_ready_executions, [:queue_name, :priority, :job_id], name: "index_solid_queue_poll_by_queue"
      add_foreign_key :solid_queue_ready_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    end

    unless table_exists?(:solid_queue_recurring_executions)
      create_table :solid_queue_recurring_executions do |t|
        t.bigint :job_id, null: false
        t.string :task_key, null: false
        t.datetime :run_at, null: false
        t.datetime :created_at, null: false
      end
      add_index :solid_queue_recurring_executions, :job_id, unique: true
      add_index :solid_queue_recurring_executions, [:task_key, :run_at], unique: true
      add_foreign_key :solid_queue_recurring_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    end

    unless table_exists?(:solid_queue_recurring_tasks)
      create_table :solid_queue_recurring_tasks do |t|
        t.string :key, null: false
        t.string :schedule, null: false
        t.string :class_name
        t.string :command, limit: 2048
        t.string :queue_name
        t.integer :priority, default: 0
        t.boolean :static, default: true, null: false
        t.text :description
        t.text :arguments
        t.timestamps null: false
      end
      add_index :solid_queue_recurring_tasks, :key, unique: true
      add_index :solid_queue_recurring_tasks, :static
    end

    unless table_exists?(:solid_queue_scheduled_executions)
      create_table :solid_queue_scheduled_executions do |t|
        t.bigint :job_id, null: false
        t.string :queue_name, null: false
        t.integer :priority, default: 0, null: false
        t.datetime :scheduled_at, null: false
        t.datetime :created_at, null: false
      end
      add_index :solid_queue_scheduled_executions, :job_id, unique: true
      add_index :solid_queue_scheduled_executions, [:scheduled_at, :priority, :job_id], name: "index_solid_queue_dispatch_all"
      add_foreign_key :solid_queue_scheduled_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
    end

    unless table_exists?(:solid_queue_semaphores)
      create_table :solid_queue_semaphores do |t|
        t.string :key, null: false
        t.integer :value, default: 1, null: false
        t.datetime :expires_at, null: false
        t.timestamps null: false
      end
      add_index :solid_queue_semaphores, :expires_at
      add_index :solid_queue_semaphores, [:key, :value]
      add_index :solid_queue_semaphores, :key, unique: true
    end

    # ===== Solid Cache =====
    unless table_exists?(:solid_cache_entries)
      create_table :solid_cache_entries do |t|
        t.binary :key, null: false
        t.binary :value, null: false
        t.datetime :created_at, null: false
        t.bigint :key_hash, null: false
        t.integer :byte_size, null: false
      end
      add_index :solid_cache_entries, :byte_size
      add_index :solid_cache_entries, [:key_hash, :byte_size]
      add_index :solid_cache_entries, :key_hash, unique: true
    end

    # ===== Solid Cable =====
    unless table_exists?(:solid_cable_messages)
      create_table :solid_cable_messages do |t|
        t.binary :channel, null: false
        t.binary :payload, null: false
        t.bigint :channel_hash, null: false
        t.datetime :created_at, null: false
      end
      add_index :solid_cable_messages, :channel
      add_index :solid_cable_messages, :channel_hash
      add_index :solid_cable_messages, :created_at
    end
  end
end
