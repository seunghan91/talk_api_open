# app/services/analytics_service.rb
class AnalyticsService
  # 일일 활성 사용자 수 (DAU)
  def self.daily_active_users(date = Date.today)
    # 해당 날짜에 활동한 사용자 수
    # 활동 기준: 로그인, 메시지 전송, 브로드캐스트 생성 등

    # 로그인한 사용자 (예시)
    login_users = User.where("last_login_at >= ? AND last_login_at < ?", date.beginning_of_day, date.end_of_day)

    # 메시지를 보낸 사용자
    message_senders = Message.where("created_at >= ? AND created_at < ?", date.beginning_of_day, date.end_of_day)
                            .pluck(:sender_id).uniq

    # 브로드캐스트를 생성한 사용자
    broadcast_creators = Broadcast.where("created_at >= ? AND created_at < ?", date.beginning_of_day, date.end_of_day)
                                 .pluck(:user_id).uniq

    # 중복 제거하여 합치기
    unique_users = (login_users.pluck(:id) + message_senders + broadcast_creators).uniq

    unique_users.count
  end

  # 신규 가입자 수
  def self.new_users(date = Date.today)
    User.where("created_at >= ? AND created_at < ?", date.beginning_of_day, date.end_of_day).count
  end

  # 브로드캐스트 통계
  def self.broadcast_stats(date = Date.today)
    # 해당 날짜에 생성된 브로드캐스트 수
    total = Broadcast.where("created_at >= ? AND created_at < ?", date.beginning_of_day, date.end_of_day).count

    # 응답이 있는 브로드캐스트 수 (대화가 생성된 브로드캐스트)
    with_replies = Broadcast.joins("INNER JOIN conversations ON broadcasts.user_id = conversations.user_a_id OR broadcasts.user_id = conversations.user_b_id")
                           .where("broadcasts.created_at >= ? AND broadcasts.created_at < ?", date.beginning_of_day, date.end_of_day)
                           .where("conversations.created_at >= broadcasts.created_at")
                           .distinct.count

    # 응답률
    response_rate = total > 0 ? (with_replies.to_f / total * 100).round(2) : 0

    {
      total: total,
      with_replies: with_replies,
      response_rate: response_rate
    }
  end

  # 대화 통계
  def self.conversation_stats(date = Date.today)
    # 해당 날짜에 생성된 대화 수
    new_conversations = Conversation.where("created_at >= ? AND created_at < ?", date.beginning_of_day, date.end_of_day).count

    # 해당 날짜에 메시지가 교환된 대화 수
    active_conversations = Conversation.joins(:messages)
                                      .where("messages.created_at >= ? AND messages.created_at < ?", date.beginning_of_day, date.end_of_day)
                                      .distinct.count

    # 해당 날짜에 전송된 메시지 수
    messages_count = Message.where("created_at >= ? AND created_at < ?", date.beginning_of_day, date.end_of_day).count

    # 대화당 평균 메시지 수
    avg_messages_per_conversation = active_conversations > 0 ? (messages_count.to_f / active_conversations).round(2) : 0

    {
      new_conversations: new_conversations,
      active_conversations: active_conversations,
      messages_count: messages_count,
      avg_messages_per_conversation: avg_messages_per_conversation
    }
  end

  # 신고 통계
  def self.report_stats(date = Date.today)
    # 해당 날짜에 생성된 신고 수
    total = Report.where("created_at >= ? AND created_at < ?", date.beginning_of_day, date.end_of_day).count

    # 상태별 신고 수
    by_status = Report.where("created_at >= ? AND created_at < ?", date.beginning_of_day, date.end_of_day)
                     .group(:status).count

    # 유형별 신고 수
    by_type = Report.where("created_at >= ? AND created_at < ?", date.beginning_of_day, date.end_of_day)
                   .group(:report_type).count

    {
      total: total,
      by_status: by_status,
      by_type: by_type
    }
  end

  # 기간별 통계 (주간, 월간)
  def self.period_stats(start_date, end_date)
    # 기간 내 일일 활성 사용자 수
    dau_by_date = (start_date..end_date).map do |date|
      { date: date, count: daily_active_users(date) }
    end

    # 기간 내 신규 가입자 수
    new_users_by_date = (start_date..end_date).map do |date|
      { date: date, count: new_users(date) }
    end

    # 기간 내 브로드캐스트 수
    broadcasts_by_date = (start_date..end_date).map do |date|
      { date: date, count: Broadcast.where("created_at >= ? AND created_at < ?", date.beginning_of_day, date.end_of_day).count }
    end

    # 기간 내 메시지 수
    messages_by_date = (start_date..end_date).map do |date|
      { date: date, count: Message.where("created_at >= ? AND created_at < ?", date.beginning_of_day, date.end_of_day).count }
    end

    {
      dau: dau_by_date,
      new_users: new_users_by_date,
      broadcasts: broadcasts_by_date,
      messages: messages_by_date
    }
  end

  # 대시보드 요약 통계
  def self.dashboard_summary
    today = Date.today
    yesterday = today - 1.day

    {
      today: {
        dau: daily_active_users(today),
        new_users: new_users(today),
        broadcasts: broadcast_stats(today)[:total],
        messages: conversation_stats(today)[:messages_count],
        reports: report_stats(today)[:total]
      },
      yesterday: {
        dau: daily_active_users(yesterday),
        new_users: new_users(yesterday),
        broadcasts: broadcast_stats(yesterday)[:total],
        messages: conversation_stats(yesterday)[:messages_count],
        reports: report_stats(yesterday)[:total]
      },
      week: period_stats(today - 7.days, today),
      month: period_stats(today - 30.days, today)
    }
  end
end
