# app/controllers/health_check_controller.rb
class HealthCheckController < ActionController::API
  def index
    render json: {
      status: "ok",
      message: "Talk API is running",
      time: Time.now.utc.iso8601,
      environment: Rails.env,
      ruby_version: RUBY_VERSION,
      rails_version: Rails.version,
      database_connected: database_connected?,
      redis_connected: redis_connected?,
      sidekiq_status: sidekiq_status
    }
  end

  def worker_status
    result = BroadcastWorker.verify_worker_setup
    render json: result
  end

  def conversations_check
    render json: conversation_stats
  end

  private

  def database_connected?
    ApplicationRecord.connection.active?
  rescue => e
    Rails.logger.error("Database connection check failed: #{e.message}")
    false
  end

  def redis_connected?
    begin
      redis_url = ENV["REDIS_URL"] || "redis://localhost:6379/0"

      # Render Redis URL 형식 수정 적용
      if redis_url.match?(/redis[s]?:\/\/[^:@]+:[^@]+@/)
        # redis://username:password@host:port -> redis://:password@host:port
        redis_url = redis_url.gsub(/redis(s)?:\/\/[^:@]+:/, 'redis\1://:')
      end

      redis_options = { url: redis_url }
      redis_options[:ssl] = true if redis_url.start_with?("rediss://") || redis_url.include?(".render.com")

      redis = Redis.new(redis_options)
      redis.ping == "PONG"
    rescue => e
      Rails.logger.error("Redis connection check failed: #{e.message}")
      Rails.logger.error("Redis URL format: #{redis_url&.gsub(/:[^:]*@/, ":****@")}")
      false
    end
  end

  def sidekiq_status
    begin
      stats = Sidekiq::Stats.new
      {
        processed: stats.processed,
        failed: stats.failed,
        enqueued: stats.enqueued,
        scheduled: stats.scheduled_size,
        processes: Sidekiq::ProcessSet.new.size,
        queues: Sidekiq::Queue.all.map { |q| { name: q.name, size: q.size } }
      }
    rescue => e
      Rails.logger.error("Sidekiq status check failed: #{e.message}")
      { error: e.message }
    end
  end

  def conversation_stats
    begin
      all_conversations = Conversation.all
      total_conversations = all_conversations.count

      # Get conversations grouped by user
      user_conversations = {}
      User.all.each do |user|
        count = Conversation.where("(user_a_id = ? AND deleted_by_a = ?) OR (user_b_id = ? AND deleted_by_b = ?)",
                                  user.id, false, user.id, false).count
        user_conversations[user.id] = {
          id: user.id,
          nickname: user.nickname,
          conversation_count: count
        }
      end

      # Get conversations with broadcast references
      broadcast_conversations = all_conversations.where.not(broadcast_id: nil).count

      {
        total_conversations: total_conversations,
        broadcast_linked_conversations: broadcast_conversations,
        user_conversations: user_conversations,
        users: User.count,
        broadcasts: Broadcast.count,
        broadcast_recipients: BroadcastRecipient.count
      }
    rescue => e
      Rails.logger.error("Conversation stats check failed: #{e.message}")
      { error: e.message }
    end
  end
end
