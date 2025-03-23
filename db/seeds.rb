# db/seeds.rb

# 환경 설정
environment_value = ENV['RAILS_ENV'] || 'development'
puts "현재 실행 환경: #{environment_value}"
puts "환경 설정 중..."
system("bin/rails db:environment:set RAILS_ENV=#{environment_value}")
puts "환경 설정 완료!"

# 기존 사용자 및 데이터 재설정
ActiveRecord::Base.connection.execute("TRUNCATE TABLE users RESTART IDENTITY CASCADE")
ActiveRecord::Base.connection.execute("TRUNCATE TABLE conversations RESTART IDENTITY CASCADE")
ActiveRecord::Base.connection.execute("TRUNCATE TABLE messages RESTART IDENTITY CASCADE")
ActiveRecord::Base.connection.execute("TRUNCATE TABLE broadcasts RESTART IDENTITY CASCADE")

# 새 테이블이 존재하는 경우 초기화
begin
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE wallets RESTART IDENTITY CASCADE")
  puts "지갑 테이블 초기화 완료!"
rescue => e
  puts "지갑 테이블 초기화 생략: #{e.message}"
end

begin
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE transactions RESTART IDENTITY CASCADE")
  puts "트랜잭션 테이블 초기화 완료!"
rescue => e
  puts "트랜잭션 테이블 초기화 생략: #{e.message}"
end

begin
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE notifications RESTART IDENTITY CASCADE")
  puts "알림 테이블 초기화 완료!"
rescue => e
  puts "알림 테이블 초기화 생략: #{e.message}"
end

# 테스트 계정 생성 (각 계정에 비밀번호 설정)
users = [
  # 베타 테스트 계정
  { phone_number: "01011111111", nickname: "A - 김철수", gender: "male", password: "test1234", password_confirmation: "test1234" },
  { phone_number: "01022222222", nickname: "B - 이영희", gender: "female", password: "test1234", password_confirmation: "test1234" },
  { phone_number: "01033333333", nickname: "C - 박지민", gender: "male", password: "test1234", password_confirmation: "test1234" },
  { phone_number: "01044444444", nickname: "D - 최수진", gender: "female", password: "test1234", password_confirmation: "test1234" },
  { phone_number: "01055555555", nickname: "E - 정민준", gender: "male", password: "test1234", password_confirmation: "test1234" },

  # 관리자 계정
  { phone_number: "01099999999", nickname: "관리자", gender: "unknown", password: "admin123", password_confirmation: "admin123" }
]

created_users = []
users.each do |user_data|
  user = User.create!(user_data)
  created_users << user
  puts "사용자 생성됨: #{user.nickname} (#{user.phone_number})"

  # 지갑 생성 (사용자 생성 후 자동 생성되도록 설정됨)
  if defined?(Wallet) && Wallet.table_exists?
    wallet = user.wallet
    if wallet
      puts "지갑 생성됨: #{user.nickname}의 지갑 (잔액: #{wallet.balance}원)"

      # 테스트용 거래 내역 추가
      if defined?(Transaction) && Transaction.table_exists?
        tx = wallet.deposit(
          1000,
          description: '첫 충전 보너스',
          payment_method: '시스템',
          metadata: { type: 'bonus', system: true }
        )
        puts "거래 생성됨: #{user.nickname}의 첫 충전 보너스 +1,000원"
      end
    else
      puts "지갑 생성 실패: #{user.nickname}"
    end
  end

  # 테스트용 알림 생성
  if defined?(Notification) && Notification.table_exists?
    notification = user.create_notification(
      'system',
      '가입을 축하합니다! 5,000원 상당의 무료 체험권이 지급되었습니다.',
      title: '가입 환영',
      metadata: { type: 'welcome' }
    )
    puts "알림 생성됨: #{user.nickname}의 가입 환영 알림"
  end
end

# 대화방 생성
conversation1 = Conversation.create!(
  user_a_id: created_users[0].id,
  user_b_id: created_users[1].id
)
puts "대화방 생성됨: #{created_users[0].nickname} ↔ #{created_users[1].nickname}"

conversation2 = Conversation.create!(
  user_a_id: created_users[0].id,
  user_b_id: created_users[2].id
)
puts "대화방 생성됨: #{created_users[0].nickname} ↔ #{created_users[2].nickname}"

# 메시지 생성
puts "메시지 생성 시작..."

if defined?(Message) && Message.table_exists? && Message.column_names.include?('message_type')
  # 샘플 오디오 파일 경로
  base_url = ENV.fetch("RENDER_EXTERNAL_URL", "http://localhost:3000")
  audio_samples = [
    "#{base_url}/audio_samples/sample_audio.wav",
    "#{base_url}/audio_samples/sample_audio1..wav",
    "#{base_url}/audio_samples/sample_audio2.wav"
  ]
  
  # 브로드캐스트 생성
  broadcast1 = Broadcast.new(
    user_id: created_users[0].id,
    text: "안녕하세요! 이것은 테스트 브로드캐스트입니다."
  )
  
  # 로컬 파일 첨부
  audio_path = Rails.root.join('public', 'audio_samples', 'sample_audio.wav')
  if File.exist?(audio_path)
    broadcast1.audio.attach(io: File.open(audio_path), filename: 'sample_audio.wav', content_type: 'audio/wav')
    broadcast1.save!
    puts "브로드캐스트 생성됨: ID #{broadcast1.id}, 발신자: #{created_users[0].nickname}"
    
    # 브로드캐스트를 이용한 대화방 생성 (이미 존재하면 기존 대화방 사용)
    conversation3 = Conversation.find_or_create_conversation(
      created_users[0].id, 
      created_users[3].id, 
      broadcast1
    )
    puts "브로드캐스트 대화방 생성됨: #{created_users[0].nickname} ↔ #{created_users[3].nickname}"
    
    # 브로드캐스트 관련 메시지가 자동 생성되었는지 확인
    broadcast_message = conversation3.messages.find_by(broadcast_id: broadcast1.id)
    unless broadcast_message
      # 브로드캐스트 메시지 수동 생성
      broadcast_message = Message.create!(
        conversation_id: conversation3.id,
        sender_id: created_users[0].id,
        broadcast_id: broadcast1.id,
        message_type: "voice"
      )
      puts "브로드캐스트 메시지 수동 생성됨: ID #{broadcast_message.id}"
    else
      puts "브로드캐스트 메시지 자동 생성됨: ID #{broadcast_message.id}"
    end
    
    # 응답 메시지 생성
    response_message = Message.create!(
      conversation_id: conversation3.id,
      sender_id: created_users[3].id,
      content: "브로드캐스트 잘 받았습니다!",
      message_type: "text"
    )
    puts "응답 메시지 생성됨: ID #{response_message.id}"
    
    # 일반 음성 메시지 생성
    audio_path2 = Rails.root.join('public', 'audio_samples', 'sample_audio1..wav')
    if File.exist?(audio_path2)
      voice_message = Message.new(
        conversation_id: conversation1.id,
        sender_id: created_users[0].id,
        message_type: "voice"
      )
      voice_message.voice_file.attach(io: File.open(audio_path2), filename: 'sample_audio1.wav', content_type: 'audio/wav')
      voice_message.save!
      puts "음성 메시지 생성됨: ID #{voice_message.id}, 대화방: #{conversation1.id}"
    else
      puts "음성 파일을 찾을 수 없음: #{audio_path2}"
    end
    
    # 텍스트 메시지 생성
    text_message = Message.create!(
      conversation_id: conversation1.id,
      sender_id: created_users[1].id,
      content: "안녕하세요! 메시지 확인했습니다.",
      message_type: "text"
    )
    puts "텍스트 메시지 생성됨: ID #{text_message.id}, 대화방: #{conversation1.id}"
  else
    puts "샘플 오디오 파일을 찾을 수 없음: #{audio_path}"
  end
else
  puts "메시지 테이블에 필요한 컬럼이 없습니다. 메시지 생성을 건너뜁니다."
end

puts "시드 데이터 생성 완료!"
