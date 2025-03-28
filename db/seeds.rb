# db/seeds.rb

puts "==== Seeding Database ===="

# 0. 환경 변수 확인 및 설정 (필요시)
puts "Environment: #{Rails.env}"

# 1. 기존 데이터 삭제 (CASCADE 옵션으로 관련 데이터 함께 삭제)
puts "Truncating tables..."
%w[users conversations messages broadcasts favorites notifications wallets transactions].each do |table_name|
  begin
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table_name} RESTART IDENTITY CASCADE")
    puts "Truncated #{table_name}"
  rescue ActiveRecord::StatementInvalid => e
    puts "Skipping truncate for #{table_name}: #{e.message}"
  end
end

# 2. 사용자 생성
puts "\nCreating users..."
users_data = [
  { phone_number: "01011111111", nickname: "김철수", gender: "male", password: "password", password_confirmation: "password" },
  { phone_number: "01022222222", nickname: "이영희", gender: "female", password: "password", password_confirmation: "password" },
  { phone_number: "01033333333", nickname: "박지민", gender: "male", password: "password", password_confirmation: "password" },
  { phone_number: "01044444444", nickname: "최수진", gender: "female", password: "password", password_confirmation: "password" },
  { phone_number: "01055555555", nickname: "정민준", gender: "male", password: "password", password_confirmation: "password" },
  { phone_number: "01099999999", nickname: "관리자", gender: "unknown", password: "admin123", password_confirmation: "admin123", admin: true } # 관리자 플래그 추가 (User 모델에 admin 컬럼 필요)
]

created_users = users_data.map do |user_data|
  user = User.create!(user_data)
  puts "Created User: #{user.nickname} (ID: #{user.id})"

  # 지갑 생성 및 초기 충전 (Wallet 모델이 있는 경우)
  if defined?(Wallet) && user.respond_to?(:wallet)
    wallet = user.wallet || user.create_wallet(balance: 0)
    puts "  - Wallet created (Balance: #{wallet.balance})"
    if defined?(Transaction)
      wallet.deposit(1000, description: "가입 축하 포인트", payment_method: "system")
      puts "  - Added 1000 points bonus transaction."
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
sample_audio_paths = Dir[Rails.root.join('public', 'audio_samples', 'sample_*.wav')]
unless sample_audio_paths.any?
  puts "\nWARN: No sample audio files found in public/audio_samples/. Voice message seeding will be limited."
end

# 함수: 오디오 파일 첨부 및 메시지 생성
def create_voice_message(conversation, sender, receiver, audio_path, broadcast = nil)
  return unless File.exist?(audio_path)

  message = conversation.messages.new(
    sender: sender,
    receiver: receiver,
    broadcast: broadcast,
    message_type: broadcast ? "broadcast_response" : "voice",
    duration: rand(5..60) # 임의의 오디오 길이 (초)
  )
  
  # Active Storage로 파일 첨부
  message.voice_file.attach(
    io: File.open(audio_path),
    filename: File.basename(audio_path),
    content_type: 'audio/wav' # 또는 실제 파일 타입에 맞게
  )
  
  if message.save
    puts "  - Created Message (ID: #{message.id}) in Conv ##{conversation.id} (Sender: #{sender.nickname}, Voice: #{File.basename(audio_path)})"
    # 메시지 생성 시 conversation의 updated_at 자동 갱신 확인 필요
    # conversation.touch if conversation.respond_to?(:touch) # 수동 갱신 필요시
  else
    puts "  - FAILED to create message: #{message.errors.full_messages.join(', ')}"
  end
  message
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
  
  # msg2를 이영희가 읽음 처리 (Message 모델에 is_read 또는 last_read_at 컬럼 필요 가정)
  if msg2 && msg2.respond_to?(:mark_as_read_by)
     msg2.mark_as_read_by(user_younghee) # 가상의 메서드, 실제 구현 필요
     puts "  - Marked message ##{msg2.id} as read by #{user_younghee.nickname}"
  elsif msg2 && msg2.respond_to?(:update)
     # 또는 직접 업데이트 (is_read 컬럼이 있고, 받는 사람이 younghee일 때)
     msg2.update(is_read: true) if msg2.receiver_id == user_younghee.id 
     puts "  - Marked message ##{msg2.id} as read (assuming is_read field exists)"
  end
  
  # conv1을 김철수가 즐겨찾기 (Conversation 모델에 favorited_by_a/b 또는 Favorite 모델 필요)
  if conv1.respond_to?(:update)
    conv1.update(favorited_by_a: true) # user_a가 김철수라고 가정
    puts "  - Favorited conversation ##{conv1.id} by #{user_cheolsu.nickname}"
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
  broadcast = Broadcast.new(user: user_cheolsu, duration: rand(10..90))
  broadcast.audio.attach(
    io: File.open(audio_path_for_broadcast),
    filename: File.basename(audio_path_for_broadcast),
    content_type: 'audio/wav'
  )
  if broadcast.save
    puts "  - Created Broadcast ##{broadcast.id} by #{user_cheolsu.nickname}"
    # 방송에 대한 대화 생성 (Conversation.create_from_broadcast 또는 find_or_create_conversation 사용)
    conv3 = Conversation.find_or_create_conversation(user_cheolsu.id, user_sujin.id, broadcast)
    if conv3
      puts "  - Created conversation ##{conv3.id} from broadcast"
      # 방송 메시지가 자동으로 생성되지 않았다면 수동 생성 (find_or_create_conversation 내부에 로직이 있을 수 있음)
      unless conv3.messages.exists?(broadcast_id: broadcast.id)
         # 필요시 방송 메시지 수동 생성 로직 추가
      end
      sleep(0.1)
      # 최수진의 답장 메시지 생성
      create_voice_message(conv3, user_sujin, user_cheolsu, sample_audio_paths.sample, broadcast)
    else 
      puts "  - FAILED to create conversation from broadcast"
    end
  else
    puts "  - FAILED to create broadcast: #{broadcast.errors.full_messages.join(', ')}"
  end
end

# 시나리오 4: 이영희 <-> 최수진 (메시지 하나 삭제됨)
puts "Creating conversation with deleted message: #{user_younghee.nickname} <-> #{user_sujin.nickname}"
conv4 = Conversation.find_or_create_conversation(user_younghee.id, user_sujin.id)
if conv4 && sample_audio_paths.any?
  msg_to_delete = create_voice_message(conv4, user_younghee, user_sujin, sample_audio_paths.sample)
  sleep(0.1)
  create_voice_message(conv4, user_sujin, user_younghee, sample_audio_paths.sample)
  
  # 메시지 삭제 처리 (Message 모델에 deleted_by_sender/receiver 또는 deleted_at 컬럼 필요 가정)
  if msg_to_delete && msg_to_delete.respond_to?(:mark_as_deleted_by)
    msg_to_delete.mark_as_deleted_by(user_sujin) # 수신자(최수진)가 삭제
    puts "  - Marked message ##{msg_to_delete.id} as deleted by #{user_sujin.nickname}"
  elsif msg_to_delete && msg_to_delete.respond_to?(:update) # 또는 deleted_at 같은 필드 업데이트
    # msg_to_delete.update(deleted_at: Time.current) # 예시
    puts "  - Marked message ##{msg_to_delete.id} as deleted (implementation specific)"
  end
end

# 시나리오 5: 김철수 <-> 정민준 (대화 자체가 삭제됨 - 김철수 측에서)
puts "Creating conversation to be deleted: #{user_cheolsu.nickname} <-> #{created_users[4].nickname}" # user_sujin -> 정민준(created_users[4])
conv5 = Conversation.find_or_create_conversation(user_cheolsu.id, created_users[4].id)
if conv5 && sample_audio_paths.any?
  create_voice_message(conv5, user_cheolsu, created_users[4], sample_audio_paths.sample)
  sleep(0.1)
  create_voice_message(conv5, created_users[4], user_cheolsu, sample_audio_paths.sample)
  
  # 김철수가 대화 삭제 (Conversation 모델에 deleted_by_a/b 플래그 필요 가정)
  if conv5.respond_to?(:update)
    if conv5.user_a_id == user_cheolsu.id
      conv5.update(deleted_by_a: true)
    elsif conv5.user_b_id == user_cheolsu.id
      conv5.update(deleted_by_b: true)
    end
    puts "  - Marked conversation ##{conv5.id} as deleted by #{user_cheolsu.nickname}"
  end
end


puts "\n==== Seeding Complete ===="
