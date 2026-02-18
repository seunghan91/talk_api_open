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
      solid_queue_status: solid_queue_status
    }
  end

  def worker_status
    render json: solid_queue_status
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

  def solid_queue_status
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

  def conversation_stats
    all_conversations = Conversation.unscoped.all
    total_conversations = all_conversations.count

    user_conversations = {}
    User.all.each do |user|
      count = Conversation.unscoped.where(
        "(user_a_id = ? AND deleted_by_a = ?) OR (user_b_id = ? AND deleted_by_b = ?)",
        user.id, false, user.id, false
      ).count
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
