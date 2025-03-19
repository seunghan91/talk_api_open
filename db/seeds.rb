# db/seeds.rb

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
Message.create!(
  conversation_id: conversation1.id,
  sender_id: created_users[0].id,
  content: "안녕하세요, 이영희님! 반갑습니다.",
  message_type: "text"
)

Message.create!(
  conversation_id: conversation1.id,
  sender_id: created_users[1].id,
  content: "네, 김철수님! 안녕하세요. 오늘 날씨가 좋네요.",
  message_type: "text"
)

Message.create!(
  conversation_id: conversation2.id,
  sender_id: created_users[0].id,
  content: "박지민님, 안녕하세요!",
  message_type: "text"
)

puts "메시지 생성 완료!"

# 브로드캐스트 메시지 생성
broadcasts = [
  { user_id: created_users[0].id, content: "안녕하세요, 모두! 김철수입니다. 오늘 날씨가 정말 좋네요!", active: true },
  { user_id: created_users[1].id, content: "이영희입니다. 새로운 앱을 사용해 보고 있어요. 정말 편리한 것 같아요!", active: true },
  { user_id: created_users[2].id, content: "안녕하세요! 박지민이라고 합니다. 다들 반가워요.", active: true }
]

broadcasts.each do |broadcast_data|
  broadcast = Broadcast.create!(broadcast_data)
  puts "브로드캐스트 생성됨: #{User.find(broadcast.user_id).nickname}의 메시지"
end

puts "시드 데이터 생성 완료!"