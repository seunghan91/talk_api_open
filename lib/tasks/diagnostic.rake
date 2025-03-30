namespace :diagnostic do
  desc "Check if Redis connection is working"
  task check_redis: :environment do
    begin
      redis_url = ENV["REDIS_URL"] || "redis://localhost:6379/0"
      puts "Checking Redis connection at: #{redis_url.gsub(/:[^:]*@/, ':****@')}"
      
      redis = Redis.new(url: redis_url)
      result = redis.ping
      
      puts "Redis connection successful: #{result}"
    rescue => e
      puts "Redis connection failed: #{e.message}"
      puts e.backtrace.join("\n")
      exit 1
    end
  end

  desc "Check all service connections"
  task check_all: :environment do
    puts "===== Service Diagnostic Report ====="
    puts "Environment: #{Rails.env}"
    puts "Ruby version: #{RUBY_VERSION}"
    puts "Rails version: #{Rails.version}"
    puts "Time: #{Time.now.utc.iso8601}"
    puts

    # Check database
    begin
      user_count = User.count
      puts "✅ Database connection successful"
      puts "  - Users: #{user_count}"
      puts "  - Conversations: #{Conversation.count}"
      puts "  - Broadcasts: #{Broadcast.count}"
      puts "  - Messages: #{Message.count}"
    rescue => e
      puts "❌ Database connection failed: #{e.message}"
    end

    # Check Redis
    begin
      redis_url = ENV["REDIS_URL"] || "redis://localhost:6379/0"
      redis = Redis.new(url: redis_url)
      result = redis.ping
      puts "✅ Redis connection successful: #{result}"
    rescue => e
      puts "❌ Redis connection failed: #{e.message}"
    end

    # Check Sidekiq
    begin
      stats = Sidekiq::Stats.new
      puts "✅ Sidekiq stats available"
      puts "  - Processed: #{stats.processed}"
      puts "  - Failed: #{stats.failed}"
      puts "  - Enqueued: #{stats.enqueued}"
      puts "  - Scheduled: #{stats.scheduled_size}"
      puts "  - Queues: #{Sidekiq::Queue.all.map { |q| "#{q.name} (#{q.size})" }.join(', ')}"
    rescue => e
      puts "❌ Sidekiq stats unavailable: #{e.message}"
    end

    puts "\n===== Environment Variables ====="
    puts "REDIS_URL set: #{ENV['REDIS_URL'] ? '✅' : '❌'}"
    puts "DATABASE_URL set: #{ENV['DATABASE_URL'] ? '✅' : '❌'}"
    puts "RAILS_ENV: #{ENV['RAILS_ENV'] || 'not set'}"
    puts "RAILS_LOG_TO_STDOUT: #{ENV['RAILS_LOG_TO_STDOUT'] || 'not set'}"
    
    puts "\n===== Done ====="
  end

  desc "Process any pending broadcasts that haven't created conversations"
  task process_pending_broadcasts: :environment do
    puts "Looking for broadcasts without conversations..."
    
    # Find all broadcasts
    broadcasts = Broadcast.all
    puts "Found #{broadcasts.count} total broadcasts"
    
    # Process each broadcast
    processed = 0
    broadcasts.each do |broadcast|
      # Check if this broadcast has associated conversations
      linked_conversations = Conversation.where(broadcast_id: broadcast.id)
      
      if linked_conversations.empty?
        puts "Processing broadcast ID #{broadcast.id} (no linked conversations)"
        
        # Create worker and process the broadcast
        worker = BroadcastWorker.new
        begin
          worker.perform(broadcast.id, 5)
          processed += 1
          puts "  ✅ Successfully processed broadcast"
        rescue => e
          puts "  ❌ Failed to process broadcast: #{e.message}"
        end
      else
        puts "Skipping broadcast ID #{broadcast.id} (already has #{linked_conversations.count} conversations)"
      end
    end
    
    puts "Completed processing #{processed} broadcasts"
  end
end