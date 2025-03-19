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

# 테스트 계정 생성 (각 계정에 비밀번호 설정)
users = [
  # 기본 테스트 계정
  { phone_number: "01011111111", nickname: "김철수", gender: "male", password: "123456", password_confirmation: "123456" },
  { phone_number: "01022222222", nickname: "이영희", gender: "female", password: "123456", password_confirmation: "123456" },
  { phone_number: "01033333333", nickname: "박지민", gender: "male", password: "123456", password_confirmation: "123456" },
  
  # 관리자 계정
  { phone_number: "01099999999", nickname: "관리자", gender: "unknown", password: "admin123", password_confirmation: "admin123" }
]

created_users = []
users.each do |user_data|
  user = User.create!(user_data)
  created_users << user
  puts "사용자 생성됨: #{user.nickname} (#{user.phone_number})"
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
  puts "샘플 음성 파일이 없어 메시지는 생성하지 않았습니다. 실제 음성 파일을 통해 메시지를 생성해야 합니다."
  
  # 참고: 실제 서버 환경에서는 아래 코드를 사용하여 음성 파일 및 텍스트 메시지를 생성할 수 있습니다.
  # 
  # # 1. 음성 메시지
  # voice_message = Message.new(
  #   conversation_id: conversation1.id,
  #   sender_id: created_users[0].id,
  #   message_type: "voice"
  # )
  # 
  # # 파일을 첨부할 경우 다음과 같이 할 수 있습니다 (파일 경로는 예시)
  # # voice_message.voice_file.attach(io: File.open('path/to/voice.m4a'), filename: 'voice.m4a')
  # # voice_message.save!
  # 
  # # 2. 텍스트 메시지
  # text_message = Message.create!(
  #   conversation_id: conversation1.id,
  #   sender_id: created_users[1].id,
  #   content: "안녕하세요! 메시지 확인했습니다.",
  #   message_type: "text"
  # )
  
  puts "메시지 생성 건너뜀! 앱에서 직접 메시지를 생성하세요."
else
  puts "메시지 테이블에 필요한 컬럼이 없습니다. 메시지 생성을 건너뜁니다."
end

# 브로드캐스트 메시지 생성
broadcasts = [
  { user_id: created_users[0].id, content: "안녕하세요, 모두! 김철수입니다. 오늘 날씨가 정말 좋네요!" },
  { user_id: created_users[1].id, content: "이영희입니다. 새로운 앱을 사용해 보고 있어요. 정말 편리한 것 같아요!" },
  { user_id: created_users[2].id, content: "안녕하세요! 박지민이라고 합니다. 다들 반가워요." }
]

broadcasts.each do |broadcast_data|
  broadcast = Broadcast.create!(broadcast_data)
  puts "브로드캐스트 생성됨: #{User.find(broadcast.user_id).nickname}의 메시지"
end

puts "시드 데이터 생성 완료!"