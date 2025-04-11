class BroadcastWorker
  include Sidekiq::Worker
  sidekiq_options queue: :broadcasts, retry: 3, backtrace: true

  # Diagnostic method for verifying worker functionality
  def self.verify_worker_setup
    begin
      # Check if worker can access the database
      user_count = User.count
      broadcast_count = Broadcast.count
      conversation_count = Conversation.count
      
      # Verify Redis connection
      redis_connection = Sidekiq.redis { |conn| conn.ping }
      
      {
        status: "ok",
        message: "BroadcastWorker setup verified",
        database_access: true,
        redis_connection: redis_connection == "PONG",
        stats: {
          users: user_count,
          broadcasts: broadcast_count,
          conversations: conversation_count
        },
        timestamp: Time.now.utc.iso8601
      }
    rescue => e
      {
        status: "error",
        message: "BroadcastWorker verification failed",
        error: e.message,
        backtrace: e.backtrace.first(5),
        timestamp: Time.now.utc.iso8601
      }
    end
  end

  def perform(broadcast_id, recipient_count = 5)
    begin
      # Log environment information for debugging
      Rails.logger.info("Worker Environment: RAILS_ENV=#{ENV['RAILS_ENV']}, REDIS_URL=#{ENV['REDIS_URL']&.gsub(/:[^:]*@/, ':****@')}")
      Rails.logger.info("브로드캐스트 처리 시작: ID #{broadcast_id}, 수신자 수 #{recipient_count}")

      broadcast = Broadcast.find_by(id: broadcast_id)
      unless broadcast
        Rails.logger.error("브로드캐스트를 찾을 수 없음: ID #{broadcast_id}")
        return
      end

      # 송신자 정보
      sender = broadcast.user
      Rails.logger.info("브로드캐스트 송신자: ID #{sender.id}, 닉네임 #{sender.nickname}")

      # 개선된 수신자 선택 알고리즘 적용
      recipients = select_optimal_recipients(sender, recipient_count)

      # 수신자 로깅
      recipient_ids = recipients.pluck(:id).join(', ')
      Rails.logger.info("브로드캐스트 수신자 선택 완료: #{recipients.count}명, IDs: [#{recipient_ids}]")

      # 브로드캐스트 수신자로 설정
      broadcast_recipients = []
      
      recipients.each do |recipient|
        # 수신자 정보 로깅
        Rails.logger.info("수신자 정보: ID #{recipient.id}, 닉네임 #{recipient.nickname}, 상태 #{recipient.status}")
        
        # 브로드캐스트 수신자 생성
        broadcast_recipient = BroadcastRecipient.create(
          broadcast: broadcast,
          user: recipient,
          status: :delivered
        )
        
        # 생성 결과 로깅
        if broadcast_recipient.persisted?
          Rails.logger.info("브로드캐스트 수신자 생성 성공: ID #{broadcast_recipient.id}")
          broadcast_recipients << broadcast_recipient
        else
          Rails.logger.error("브로드캐스트 수신자 생성 실패: 수신자 ID #{recipient.id}, 오류: #{broadcast_recipient.errors.full_messages.join(', ')}")
        end
      end

      # 브로드캐스트 수신자와 대화 자동 생성 확인
      broadcast_recipients.each do |br|
        begin
          Rails.logger.info("브로드캐스트 수신자 (ID #{br.user_id})와 대화 처리 시작")
          
          # 대화 생성 - Conversation.find_or_create_conversation 메소드 사용
          conversation = Conversation.find_or_create_conversation(
            broadcast.user_id, 
            br.user_id, 
            broadcast
          )
          
          Rails.logger.info("대화 처리 완료: ID #{conversation.id}")
          
          # 브로드캐스트 발신자는 대화방이 보이도록, 수신자는 보이지 않도록 설정
          # (수신자는 응답할 때만 대화방이 보임)
          if conversation.user_a_id == br.user_id
            # 수신자가 user_a인 경우
            conversation.update(deleted_by_a: true)  # 수신자에게는 삭제된 상태로 설정
            conversation.update(deleted_by_b: false) # 발신자에게는 보이도록 설정
          elsif conversation.user_b_id == br.user_id
            # 수신자가 user_b인 경우
            conversation.update(deleted_by_b: true)  # 수신자에게는 삭제된 상태로 설정
            conversation.update(deleted_by_a: false) # 발신자에게는 보이도록 설정
          end
          
          # 대화에 브로드캐스트 메시지 추가
          message = Message.create!(
            conversation: conversation,
            sender_id: broadcast.user_id,
            broadcast_id: broadcast.id,
            message_type: "broadcast"
          )
          
          Rails.logger.info("대화에 브로드캐스트 메시지 추가 성공: 메시지 ID #{message.id}")
          
          # 대화 업데이트 시간 갱신
          conversation.touch
          
        rescue => e
          Rails.logger.error("대화 생성 또는 메시지 추가 실패: #{e.message}\n#{e.backtrace.join("\n")}")
        end
      end

      # 푸시 알림 전송
      recipients.each do |recipient|
        next unless recipient.broadcast_push_enabled && recipient.push_token.present?

        begin
          PushNotificationService.new.send_broadcast_notification(
            recipient,
            broadcast
          )
          Rails.logger.info("푸시 알림 전송 성공: 수신자 ID #{recipient.id}")
        rescue => e
          Rails.logger.error("푸시 알림 전송 실패 (수신자: #{recipient.id}): #{e.message}")
        end
      end

      Rails.logger.info("브로드캐스트 처리 완료: ID #{broadcast_id}")
    rescue Redis::CannotConnectError, RedisClient::CannotConnectError => e
      Rails.logger.error("Redis 연결 실패: #{e.message}")
      raise e
    rescue => e
      Rails.logger.error("브로드캐스트 처리 실패: #{e.message}\n#{e.backtrace.join("\n")}")
      raise e
    end
  end

  private

  # 최적의 수신자를 선택하는 개선된 알고리즘
  def select_optimal_recipients(sender, recipient_count)
    Rails.logger.info("피드백 기반 수신자 선택 알고리즘 실행 - 송신자: #{sender.id}, 요청 수신자 수: #{recipient_count}")
    
    # 디버깅: 무조건 더 많은 사용자를 선택하도록 수정
    all_users = User.where.not(id: sender.id).to_a
    
    if all_users.empty?
      Rails.logger.warn("사용 가능한 수신자가 없음, 서버 시드 데이터 확인 필요")
      return []
    end
    
    # 수신자가 부족한 경우 처리
    if all_users.count < recipient_count
      Rails.logger.info("사용 가능한 수신자가 #{all_users.count}명뿐이므로 요청 수 #{recipient_count}명에 미달")
      return all_users
    end
    
    # 모든 사용자를 선택하되, 최대 수신자 수 제한
    return all_users.sample(recipient_count)
    
    # 기본 필터: 활성 상태, 전화번호 있는 사용자 (기존 코드 주석 처리)
    # base_query = User.where.not(id: sender.id)
    #                .where(status: :active)
    #                .where.not(phone_number: nil)

    # 1. 과거 응답률 기반 점수 계산
    response_scores = calculate_response_scores(sender)
    
    # 2. 최근 상호작용 기반 점수 계산
    interaction_scores = calculate_interaction_scores(sender)
    
    # 3. 사용자 선호도 반영 (성별, 나이대, 지역 등)
    preference_scores = calculate_preference_scores(sender)
    
    # 모든 활성 사용자 ID와 초기 점수 (0점) 매핑
    all_active_users = base_query.pluck(:id)
    user_scores = all_active_users.each_with_object({}) { |user_id, scores| scores[user_id] = 0.0 }
    
    # 각 점수 결합 (가중치 적용)
    response_weight = 0.5   # 응답률 가중치
    interaction_weight = 0.3 # 상호작용 가중치
    preference_weight = 0.2  # 선호도 가중치
    
    all_active_users.each do |user_id|
      # 각 점수 요소가 nil인 경우 0으로 처리
      response_score = response_scores[user_id] || 0
      interaction_score = interaction_scores[user_id] || 0
      preference_score = preference_scores[user_id] || 0
      
      # 최종 점수 계산
      user_scores[user_id] = 
        (response_score * response_weight) + 
        (interaction_score * interaction_weight) + 
        (preference_score * preference_weight)
    end
    
    # 높은 점수 순으로 정렬하여 사용자 ID 배열 생성
    sorted_user_ids = user_scores.sort_by { |_, score| -score }.map { |user_id, _| user_id }
    
    # 랜덤 요소 도입 (상위 20%는 항상 포함, 나머지는 점수에 기반한 확률로 선택)
    top_tier_count = (sorted_user_ids.size * 0.2).ceil
    top_tier_ids = sorted_user_ids.first(top_tier_count)
    
    remaining_ids = sorted_user_ids[top_tier_count..-1] || []
    
    # 확률적 선택 (점수가 높을수록 선택 확률 증가)
    selected_ids = top_tier_ids.dup # 상위 20%는 항상 포함
    
    # 남은 사용자 중 추가로 필요한 수만큼 확률적으로 선택
    remaining_count = [recipient_count - top_tier_ids.size, 0].max
    
    if remaining_count > 0 && !remaining_ids.empty?
      # 남은 사용자들의 점수 추출
      remaining_scores = remaining_ids.map { |id| user_scores[id] }
      
      # 최소 점수가 0보다 작으면 모든 점수에 최소값의 절대값을 더해 양수로 만듦
      min_score = remaining_scores.min
      if min_score < 0
        remaining_scores = remaining_scores.map { |score| score + min_score.abs + 0.1 }
      end
      
      # 점수를 확률로 변환 (총합 = 1)
      sum_scores = remaining_scores.sum
      probabilities = remaining_scores.map { |score| sum_scores > 0 ? score / sum_scores : 1.0 / remaining_ids.size }
      
      # 확률적 샘플링
      additional_indices = weighted_sample(probabilities, remaining_count)
      additional_ids = additional_indices.map { |idx| remaining_ids[idx] }
      
      selected_ids.concat(additional_ids)
    end
    
    # 선택된 ID에 해당하는 사용자들 조회
    selected_users = User.where(id: selected_ids).to_a
    
    # 선택된 사용자 수가 요청 수보다 적으면 랜덤으로 추가
    if selected_users.size < recipient_count
      additional_random_users = base_query.where.not(id: selected_ids)
                                        .order("RANDOM()")
                                        .limit(recipient_count - selected_users.size)
      selected_users.concat(additional_random_users)
    end
    
    # 로깅
    Rails.logger.info("피드백 기반 수신자 선택 결과: #{selected_users.size}명 선택됨")
    selected_users.each_with_index do |user, index|
      score = user_scores[user.id] || 'N/A'
      Rails.logger.info("- 선택된 수신자 #{index+1}: ID #{user.id}, 닉네임: #{user.nickname}, 점수: #{score}")
    end
    
    selected_users
  end
  
  # 과거 응답률 기반 점수 계산
  def calculate_response_scores(sender)
    scores = {}
    
    # 최근 3개월 내 브로드캐스트 데이터 조회
    recent_broadcasts = sender.broadcasts.where('created_at > ?', 3.months.ago)
    
    # 각 사용자별 응답률 계산
    recipients_data = BroadcastRecipient.where(broadcast_id: recent_broadcasts.pluck(:id))
                                        .includes(:user)
                                        .group_by(&:user_id)
    
    recipients_data.each do |user_id, receipts|
      # 받은 브로드캐스트 수
      received_count = receipts.size
      
      # 응답한 브로드캐스트 수 (대화 시작 여부로 판단)
      responded_count = 0
      
      receipts.each do |receipt|
        broadcast = receipt.broadcast
        
        # 해당 브로드캐스트의 송신자와 수신자 간의 대화 확인
        conversation = Conversation.where(
          "(user_a_id = ? AND user_b_id = ?) OR (user_a_id = ? AND user_b_id = ?)",
          sender.id, user_id, user_id, sender.id
        ).first
        
        if conversation
          # 브로드캐스트 이후 수신자가 보낸 메시지가 있는지 확인
          responded = conversation.messages.where(sender_id: user_id)
                                 .where('created_at > ?', broadcast.created_at)
                                 .exists?
          
          responded_count += 1 if responded
        end
      end
      
      # 응답률 계산 (0~1 사이 값)
      response_rate = received_count > 0 ? responded_count.to_f / received_count : 0
      
      # 응답률 기반 점수 (0~100)
      scores[user_id] = response_rate * 100
    end
    
    scores
  end
  
  # 상호작용 기반 점수 계산
  def calculate_interaction_scores(sender)
    scores = {}
    
    # 송신자와 다른 사용자들 간의 대화 조회
    conversations = Conversation.where("user_a_id = ? OR user_b_id = ?", sender.id, sender.id)
    
    conversations.each do |conv|
      # 상대방 ID 추출
      other_user_id = conv.user_a_id == sender.id ? conv.user_b_id : conv.user_a_id
      
      # 최근 2개월 내 메시지 수 카운트
      recent_messages_count = conv.messages.where('created_at > ?', 2.months.ago).count
      
      # 최근 대화 활동 점수 (최대 100점)
      recency_score = 0
      last_message = conv.messages.order(created_at: :desc).first
      
      if last_message
        days_since_last_message = (Time.current - last_message.created_at) / 1.day
        
        # 최근 대화일수록 높은 점수 (최대 7일 전까지)
        if days_since_last_message <= 7
          recency_score = 100 * (1 - days_since_last_message / 7)
        end
      end
      
      # 대화 빈도 점수 (최대 100점)
      frequency_score = [recent_messages_count, 100].min
      
      # 두 점수 평균으로 최종 상호작용 점수 계산
      scores[other_user_id] = (recency_score + frequency_score) / 2.0
    end
    
    scores
  end
  
  # 선호도 기반 점수 계산
  def calculate_preference_scores(sender)
    scores = {}
    
    # 송신자의 선호 속성 추출 (성별, 나이대, 지역 등)
    sender_gender = sender.gender
    sender_age_group = sender.age_group
    sender_region = sender.region
    
    # 활성 사용자들의 속성과 매칭해 점수 계산
    User.where(status: :active).where.not(id: sender.id).find_each do |user|
      score = 0
      
      # 성별 점수 (다른 성별 선호 가정)
      if sender_gender.present? && user.gender.present?
        score += 30 if sender_gender != user.gender
      end
      
      # 나이대 점수 (비슷한 나이대 선호 가정)
      if sender_age_group.present? && user.age_group.present?
        age_diff = (sender_age_group.to_i - user.age_group.to_i).abs
        score += 30 * (1 - [age_diff, 3].min / 3.0)
      end
      
      # 지역 점수 (같은 지역 선호 가정)
      if sender_region.present? && user.region.present?
        score += 40 if sender_region == user.region
      end
      
      scores[user.id] = score
    end
    
    scores
  end
  
  # 가중치 기반 샘플링 함수
  def weighted_sample(probabilities, count)
    indices = []
    count = [probabilities.length, count].min
    
    count.times do
      # 이미 선택된 인덱스 제외
      available_indices = (0...probabilities.length).to_a - indices
      available_probs = available_indices.map { |i| probabilities[i] }
      
      # 남은 확률의 합 계산
      sum_probs = available_probs.sum
      
      # 확률 정규화
      normalized_probs = available_probs.map { |p| sum_probs > 0 ? p / sum_probs : 1.0 / available_probs.size }
      
      # 누적 확률 계산
      cumulative_probs = []
      sum = 0
      normalized_probs.each do |p|
        sum += p
        cumulative_probs << sum
      end
      
      # 랜덤 값 생성 (0~1)
      r = rand
      
      # 이진 검색으로 해당 구간 찾기
      selected_idx = nil
      
      cumulative_probs.each_with_index do |cp, idx|
        if r <= cp
          selected_idx = available_indices[idx]
          break
        end
      end
      
      # 선택된 인덱스가 없으면 (반올림 오류 등의 이유로) 첫 번째 사용 가능한 인덱스 선택
      selected_idx ||= available_indices.first
      
      indices << selected_idx if selected_idx
    end
    
    indices
  end
end
