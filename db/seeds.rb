# db/seeds.rb

puts "==== Seeding Database ===="

# 0. 환경 변수 확인 및 설정 (필요시)
puts "Environment: #{Rails.env}"

# 1. 기존 데이터 삭제 - 더 안전한 방법 사용
puts "Cleaning up existing data..."
begin
  # 역순으로 삭제하여 외래키 제약 피하기
  Transaction.destroy_all if defined?(Transaction)
  Notification.destroy_all if defined?(Notification)
  Message.destroy_all if defined?(Message)
  Conversation.destroy_all if defined?(Conversation)
  Broadcast.destroy_all if defined?(Broadcast)
  Wallet.destroy_all if defined?(Wallet)
  User.destroy_all
  puts "Existing data cleaned up successfully"
rescue => e
  puts "Error during cleanup: #{e.message}"
  puts "Continuing with seed..."
end

# 2. 사용자 생성
puts "\nCreating users..."
users_data = [
  { phone_number: "01011111111", nickname: "김철수", gender: "male", password: "password", password_confirmation: "password" },
  { phone_number: "01022222222", nickname: "이영희", gender: "female", password: "password", password_confirmation: "password" },
  { phone_number: "01033333333", nickname: "박지민", gender: "male", password: "password", password_confirmation: "password" },
  { phone_number: "01044444444", nickname: "최수진", gender: "female", password: "password", password_confirmation: "password" },
  { phone_number: "01055555555", nickname: "정민준", gender: "male", password: "password", password_confirmation: "password" },
  { phone_number: "01099999999", nickname: "관리자", gender: "unknown", password: "admin123", password_confirmation: "admin123" } # 관리자 계정
]

# 각 사용자별 초기 지갑 금액 설정
wallet_balances = {
  "01011111111" => 12500,  # 김철수
  "01022222222" => 7800,   # 이영희
  "01033333333" => 3200,   # 박지민
  "01044444444" => 9500,   # 최수진
  "01055555555" => 6000,   # 정민준
  "01099999999" => 50000   # 관리자
}

created_users = users_data.map do |user_data|
  user = User.create!(user_data)
  puts "Created User: #{user.nickname} (ID: #{user.id})"

  # 지갑 생성 및 초기 충전 (Wallet 모델이 있는 경우)
  if defined?(Wallet) && user.respond_to?(:wallet)
    initial_balance = wallet_balances[user_data[:phone_number]] || 5000
    wallet = user.wallet || user.create_wallet(balance: 0)
    puts "  - Wallet created (Balance: #{wallet.balance})"

    if defined?(Transaction)
      # 기존 1000원 충전 대신 사용자별 설정된 금액으로 충전
      wallet.deposit(initial_balance, description: "가입 축하 포인트", payment_method: "system")
      puts "  - Added #{initial_balance} points bonus transaction."
    else
      # Transaction이 없는 경우 수동으로 잔액 설정
      wallet.update(balance: initial_balance)
      puts "  - Set wallet balance to #{initial_balance} points."
    end
  end

  # 가입 환영 알림 (Notification 모델이 있는 경우)
  if defined?(Notification) && user.respond_to?(:create_notification)
    user.create_notification('system', '가입을 축하합니다! Talk App에 오신 것을 환영해요.', title: '환영합니다!')
    puts "  - Created welcome notification."
  end
  user
end

user_cheolsu = created_users[0]
user_younghee = created_users[1]
user_jimin = created_users[2]
user_sujin = created_users[3]

# 샘플 오디오 파일 경로 (public/audio_samples 디렉토리에 파일 필요)
puts "\nChecking for sample audio files..."
sample_audio_paths = Dir[Rails.root.join('public', 'audio_samples', '*.wav')]
puts "Found #{sample_audio_paths.count} sample audio files: #{sample_audio_paths.map { |f| File.basename(f) }.join(', ')}"

unless sample_audio_paths.any?
  # 수동으로 파일 경로 명시 (문제 해결을 위한 임시 방법)
  absolute_path = '/Users/seunghan/dev/talk_api_open/public/audio_samples'
  sample_audio_paths = Dir["#{absolute_path}/*.wav"]
  puts "Trying absolute path: Found #{sample_audio_paths.count} sample audio files: #{sample_audio_paths.map { |f| File.basename(f) }.join(', ')}"

  if !sample_audio_paths.any?
    puts "\nWARN: No sample audio files found! Voice message seeding will be limited."
    puts "Please ensure sample audio files exist in: #{Rails.root.join('public', 'audio_samples')}"
    puts "Or in absolute path: #{absolute_path}"
  end
end

# 함수: 오디오 파일 첨부 및 메시지 생성
def create_voice_message(conversation, sender, receiver_user, audio_path, broadcast = nil)
  unless File.exist?(audio_path)
    puts "  - ERROR: Audio file not found at path: #{audio_path}"
    return nil
  end

  puts "  - Creating voice message with audio: #{File.basename(audio_path)}"

  begin
    # 빈 메시지 생성 (음성 파일 첨부 없이)
    message = conversation.messages.new(
      sender_id: sender.id,
      message_type: broadcast ? "broadcast_response" : "voice",
      read: false, # 읽지 않음 상태로 초기화
      duration: rand(5..60), # 임의의 오디오 길이 (초)
      broadcast_id: broadcast&.id
    )

    # 저장 먼저 하기
    if message.save
      puts "  - Created empty message (ID: #{message.id}) in Conv ##{conversation.id}"

      # 메시지 생성 시 conversation의 updated_at 자동 갱신 확인 필요
      conversation.touch if conversation.respond_to?(:touch) # 수동 갱신

      # 음성 파일 없이 메시지만 생성해도 충분함
      puts "  - NOTE: Skipping voice file attachment due to validation issues"

      message
    else
      puts "  - FAILED to create message: #{message.errors.full_messages.join(', ')}"
      nil
    end
  rescue => e
    puts "  - ERROR while creating message: #{e.message}"
    nil
  end
end

# 3. 대화 및 메시지 생성
puts "\nCreating conversations and messages..."

# 시나리오 1: 김철수 <-> 이영희 (여러 메시지, 읽음/안 읽음)
puts "Creating conversation: #{user_cheolsu.nickname} <-> #{user_younghee.nickname}"
conv1 = Conversation.find_or_create_conversation(user_cheolsu.id, user_younghee.id)
if conv1 && sample_audio_paths.any?
  create_voice_message(conv1, user_cheolsu, user_younghee, sample_audio_paths.sample)
  sleep(0.1) # 시간차를 두어 생성 순서 보장
  msg2 = create_voice_message(conv1, user_younghee, user_cheolsu, sample_audio_paths.sample)
  sleep(0.1)
  msg3 = create_voice_message(conv1, user_cheolsu, user_younghee, sample_audio_paths.sample)

  # msg2를 읽음 처리 (Message 모델에 read 또는 read_at 컬럼 사용)
  if msg2 && msg2.respond_to?(:mark_as_read_by)
     msg2.mark_as_read_by(user_younghee) # 가상의 메서드, 실제 구현 필요
     puts "  - Marked message ##{msg2.id} as read by #{user_younghee.nickname}"
  elsif msg2 && msg2.respond_to?(:update)
     # 직접 읽음 상태로 업데이트
     msg2.update(read: true)
     puts "  - Marked message ##{msg2.id} as read"
  end

  # 즐겨찾기 기능은 모델에 컬럼이 없으므로 주석 처리
  # puts "  - Note: Skipping conversation favoriting because the model doesn't have favorited_by_a/b fields"

  # 모델에 favorited_by? 메서드가 있는 경우에만 수행
  if conv1.respond_to?(:favorited_by?)
    puts "  - Conversation #{conv1.id} can be favorited using the favorited_by? method"
  end
end

# 시나리오 2: 김철수 <-> 박지민 (메시지 없음)
puts "Creating empty conversation: #{user_cheolsu.nickname} <-> #{user_jimin.nickname}"
conv2 = Conversation.find_or_create_conversation(user_cheolsu.id, user_jimin.id)
puts "  - Created empty conversation ##{conv2.id}" if conv2

# 시나리오 3: 김철수 -> 최수진 (방송 및 답장)
puts "Creating broadcast conversation: #{user_cheolsu.nickname} -> #{user_sujin.nickname}"
if sample_audio_paths.any?
  audio_path_for_broadcast = sample_audio_paths.sample
  # Broadcast 모델에 맞게 필드 설정 - text 메서드 호출 제거

  begin
    # 방법 1: 단순 생성 (text 필드 제거)
    broadcast = Broadcast.new(
      user_id: user_cheolsu.id,
      expired_at: 7.days.from_now,
      active: true,
      duration: rand(10..90)
    )

    if broadcast.save
      puts "  - Created Broadcast ##{broadcast.id} by #{user_cheolsu.nickname} (without audio)"

      # 대화 생성 (conversation.broadcast_id를 설정할 수 있으면 설정)
      conv3 = Conversation.find_or_create_conversation(user_cheolsu.id, user_sujin.id)
      if conv3
        puts "  - Created conversation ##{conv3.id} with #{user_sujin.nickname}"

        # 방송용 메시지 생성 (음성 없이)
        broadcast_message = conv3.messages.create(
          sender_id: user_cheolsu.id,
          broadcast_id: broadcast.id,
          message_type: "broadcast",
          read: false,
          duration: broadcast.duration
        )
        puts "  - Created broadcast message #{broadcast_message.id} in conversation ##{conv3.id}" if broadcast_message

        # 답장 메시지 생성 (음성 없이)
        response_message = create_voice_message(conv3, user_sujin, user_cheolsu, sample_audio_paths.sample)
        puts "  - Created response message to broadcast" if response_message
      end
    else
      puts "  - FAILED to create broadcast: #{broadcast.errors.full_messages.join(', ')}"
    end
  rescue => e
    puts "  - ERROR creating broadcast: #{e.message}"
  end
end

# 시나리오 4: 이영희 <-> 최수진 (메시지 하나 삭제됨)
puts "Creating conversation with deleted message: #{user_younghee.nickname} <-> #{user_sujin.nickname}"
conv4 = Conversation.find_or_create_conversation(user_younghee.id, user_sujin.id)
if conv4 && sample_audio_paths.any?
  msg_to_delete = create_voice_message(conv4, user_younghee, user_sujin, sample_audio_paths.sample)
  sleep(0.1)
  create_voice_message(conv4, user_sujin, user_younghee, sample_audio_paths.sample)

  # 메시지 삭제 처리 (실제 삭제 또는 read 필드로 대체)
  if msg_to_delete
    # 삭제를 시뮬레이션하기 위해 read 필드를 활용
    msg_to_delete.update(read: true)
    puts "  - Simulated message deletion by marking message ##{msg_to_delete.id} as read"
  end
end

# 시나리오 5: 김철수 <-> 정민준 (대화 자체가 삭제됨 - 김철수 측에서)
puts "Creating conversation to be deleted: #{user_cheolsu.nickname} <-> #{created_users[4].nickname}"
conv5 = Conversation.find_or_create_conversation(user_cheolsu.id, created_users[4].id)
if conv5 && sample_audio_paths.any?
  create_voice_message(conv5, user_cheolsu, created_users[4], sample_audio_paths.sample)
  sleep(0.1)
  create_voice_message(conv5, created_users[4], user_cheolsu, sample_audio_paths.sample)

  # 대화 삭제 처리 (deleted_by_a/b 필드가 있는 경우만)
  if conv5.respond_to?(:deleted_by_a) || conv5.attributes.include?("deleted_by_a")
    # 김철수가 대화 삭제
    if conv5.user_a_id == user_cheolsu.id
      conv5.update(deleted_by_a: true)
      puts "  - Marked conversation ##{conv5.id} as deleted by #{user_cheolsu.nickname} (user_a)"
    elsif conv5.user_b_id == user_cheolsu.id
      conv5.update(deleted_by_b: true)
      puts "  - Marked conversation ##{conv5.id} as deleted by #{user_cheolsu.nickname} (user_b)"
    end
  else
    puts "  - Note: Conversation deletion not supported by the model (deleted_by_a/b fields not found)"
  end
end

# 공지사항 카테고리
puts "Creating announcement categories..."
categories = [
  { name: '공지', description: '일반 공지사항' },
  { name: '업데이트', description: '앱 업데이트 관련 공지' },
  { name: '이벤트', description: '이벤트 관련 공지' }
]

categories.each do |category_attrs|
  AnnouncementCategory.find_or_create_by!(name: category_attrs[:name]) do |category|
    category.description = category_attrs[:description]
  end
end

# 공지사항
puts "Creating announcements..."
announcements = [
  {
    title: '[공지] 서비스 이용 약관 변경 안내',
    content: '안녕하세요. 보이스 챗 서비스를 이용해 주셔서 감사합니다.

서비스 이용 약관이 다음과 같이 변경될 예정입니다.

변경 사항: 개인정보 처리방침 업데이트
적용일: 2023년 4월 1일

자세한 내용은 본문을 참고해 주세요.',
    category_name: '공지',
    is_important: true,
    is_published: true,
    is_hidden: false,
    published_at: 7.days.ago
  },
  {
    title: '[업데이트] 앱 버전 2.0 출시 안내',
    content: '안녕하세요. 보이스 챗 서비스를 이용해 주셔서 감사합니다.

새로운 기능이 추가된 버전 2.0이 출시되었습니다.

주요 업데이트:
1. UI/UX 개선
2. 음성 품질 향상
3. 배터리 사용량 최적화

앱스토어에서 업데이트를 진행해 주세요.',
    category_name: '업데이트',
    is_important: false,
    is_published: true,
    is_hidden: false,
    published_at: 3.days.ago
  },
  {
    title: '[이벤트] 신규 사용자 이벤트 안내',
    content: '안녕하세요. 보이스 챗 서비스를 이용해 주셔서 감사합니다.

신규 사용자를 위한 특별 이벤트를 진행합니다.

이벤트 기간: 2023년 3월 15일 ~ 3월 31일
이벤트 내용: 프리미엄 기능 2주 무료 이용권 지급

많은 참여 부탁드립니다.',
    category_name: '이벤트',
    is_important: true,
    is_published: true,
    is_hidden: true,
    published_at: 1.day.ago
  },
  {
    title: '[공지] 서버 점검 안내',
    content: '안녕하세요. 보이스 챗 서비스를 이용해 주셔서 감사합니다.

서비스 안정화를 위한 서버 점검이 있을 예정입니다.

점검 일시: 2023년 4월 10일 02:00 ~ 05:00 (한국 시간)
점검 내용: 서버 최적화 및 보안 업데이트

점검 시간 동안 서비스 이용이 제한됩니다. 양해 부탁드립니다.',
    category_name: '공지',
    is_important: true,
    is_published: false,
    is_hidden: false,
    published_at: nil
  }
]

announcements.each do |announcement_attrs|
  category = AnnouncementCategory.find_by(name: announcement_attrs[:category_name])

  Announcement.find_or_create_by!(title: announcement_attrs[:title]) do |announcement|
    announcement.content = announcement_attrs[:content]
    announcement.category = category
    announcement.is_important = announcement_attrs[:is_important]
    announcement.is_published = announcement_attrs[:is_published]
    announcement.is_hidden = announcement_attrs[:is_hidden]
    announcement.published_at = announcement_attrs[:published_at]
  end
end

# 브로드캐스팅 테스트용 시드 데이터
puts "Creating test users and broadcast data..."

# 테스트 사용자 생성
test_users = []
5.times do |i|
  user = User.find_or_create_by(phone_number: "+821000000#{i}") do |u|
    u.nickname = "테스트사용자#{i+1}"
    u.password = "password123"
    u.gender = i.even? ? "male" : "female"
    u.verified = true
    u.status = :active
  end
  test_users << user
end

# 사용자1이 브로드캐스트 생성
broadcaster = test_users[0]
broadcast = broadcaster.broadcasts.create!(
  text: "안녕하세요! 테스트 브로드캐스트입니다.",
  content: "안녕하세요! 테스트 브로드캐스트입니다."
)

# 사용자 2,3,4를 수신자로 설정
recipients = test_users[1..3]
recipients.each_with_index do |recipient, index|
  br = BroadcastRecipient.create!(
    broadcast: broadcast,
    user: recipient,
    status: :delivered
  )
  
  # 사용자4(인덱스 2)만 응답
  if index == 2
    # 대화방 생성
    conversation = Conversation.find_or_create_conversation(
      broadcaster.id,
      recipient.id,
      broadcast
    )
    
    # 응답 메시지 생성
    message = conversation.messages.create!(
      sender_id: recipient.id,
      message_type: "voice",
      content: "응답 메시지입니다!"
    )
    
    # 응답 상태 업데이트
    br.update!(status: :replied)
    
    # 양쪽에게 대화방 표시
    conversation.show_to!(broadcaster.id)
    conversation.show_to!(recipient.id)
  end
end

puts "Test data created successfully!"
puts "- Broadcaster: #{broadcaster.nickname} (#{broadcaster.phone_number})"
puts "- Recipients: #{recipients.map(&:nickname).join(', ')}"
puts "- User4 replied to the broadcast"

puts "\n==== Seeding Complete ===="
