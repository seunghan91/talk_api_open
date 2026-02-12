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
      solid_queue_status: solid_queue_status
    }
  end

  def worker_status
    render json: solid_queue_status
  end

  def conversations_check
    render json: conversation_stats
  end

  def debug_redis
    render json: {
      redis_url_env: ENV["REDIS_URL"],
      render_redis_url_env: ENV["RENDER_REDIS_URL"],
      redis_host_env: ENV["REDIS_HOST"],
      redis_port_env: ENV["REDIS_PORT"],
      all_redis_related: ENV.select { |k, v| k.downcase.include?("redis") }
    }
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

      if redis_url.match?(/redis[s]?:\/\/[^:@]+:[^@]+@/)
        redis_url = redis_url.gsub(/redis(s)?:\/\/[^:@]+:/, 'redis\1://:')
      end

      redis_options = { url: redis_url }
      redis_options[:ssl] = true if redis_url.start_with?("rediss://") || redis_url.include?(".render.com")

      redis = Redis.new(redis_options)
      redis.ping == "PONG"
    rescue => e
      Rails.logger.error("Redis connection check failed: #{e.message}")
      false
    end
  end

  def solid_queue_status
    begin
      {
        ready: SolidQueue::ReadyExecution.count,
        scheduled: SolidQueue::ScheduledExecution.count,
        claimed: SolidQueue::ClaimedExecution.count,
        failed: SolidQueue::FailedExecution.count,
        recurring: SolidQueue::RecurringTask.count
      }
    rescue => e
      Rails.logger.error("Solid Queue status check failed: #{e.message}")
      { error: e.message }
    end
  end

  def conversation_stats
    begin
      all_conversations = Conversation.unscoped.all
      total_conversations = all_conversations.count

      user_conversations = {}
      User.all.each do |user|
        count = Conversation.unscoped.where("(user_a_id = ? AND deleted_by_a = ?) OR (user_b_id = ? AND deleted_by_b = ?)",
                                  user.id, false, user.id, false).count
        user_conversations[user.id] = {
          id: user.id,
          nickname: user.nickname,
          conversation_count: count
        }
      end

      broadcast_conversations = all_conversations.where.not(broadcast_id: nil).count

      {
        total_conversations: total_conversations,
        broadcast_linked_conversations: broadcast_conversations,
        user_conversations: user_conversations,
        users: User.count,
        broadcasts: Broadcast.unscoped.count,
        broadcast_recipients: BroadcastRecipient.count
      }
    rescue => e
      Rails.logger.error("Conversation stats check failed: #{e.message}")
      { error: e.message }
    end
  end
end
