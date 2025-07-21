#!/usr/bin/env ruby
# 브로드캐스트 흐름 테스트 스크립트
# 실행 방법: rails runner scripts/test_broadcast_flow.rb

puts "=== 브로드캐스트 흐름 테스트 시작 ==="

# 1. 테스트 사용자 확인
puts "\n1. 테스트 사용자 확인"
user1 = User.find_by(phone_number: "+8210000000")
user2 = User.find_by(phone_number: "+8210000001")
user3 = User.find_by(phone_number: "+8210000002")
user4 = User.find_by(phone_number: "+8210000003")

if [user1, user2, user3, user4].any?(&:nil?)
  puts "❌ 테스트 사용자가 없습니다. db:seed를 먼저 실행하세요."
  exit 1
end

puts "✅ 테스트 사용자 확인 완료"
puts "  - 사용자1: #{user1.nickname}"
puts "  - 사용자2: #{user2.nickname}"
puts "  - 사용자3: #{user3.nickname}"
puts "  - 사용자4: #{user4.nickname}"

# 2. 브로드캐스트 생성
puts "\n2. 브로드캐스트 생성 (사용자1이 발송)"
broadcast = user1.broadcasts.create!(
  text: "테스트 브로드캐스트 #{Time.now.strftime('%H:%M:%S')}",
  content: "테스트 브로드캐스트 내용입니다."
)
puts "✅ 브로드캐스트 생성 완료 (ID: #{broadcast.id})"

# 3. BroadcastWorker 실행 (수신자 선택)
puts "\n3. 브로드캐스트 전송 (BroadcastWorker 실행)"
BroadcastWorker.new.perform(broadcast.id, 3)
puts "✅ 브로드캐스트 전송 완료"

# 4. 수신자 확인
puts "\n4. 수신자 상태 확인"
broadcast.reload
broadcast.broadcast_recipients.each do |recipient|
  puts "  - #{recipient.user.nickname}: #{recipient.status}"
end

# 5. 사용자4가 응답
puts "\n5. 사용자4가 브로드캐스트에 응답"
recipient4 = broadcast.broadcast_recipients.find_by(user: user4)
if recipient4
  # 대화방 생성
  conversation = Conversation.find_or_create_conversation(user4.id, user1.id, broadcast)
  
  # 응답 메시지 생성
  message = conversation.messages.create!(
    sender_id: user4.id,
    message_type: "voice",
    content: "사용자4의 응답 메시지입니다."
  )
  
  # 응답 상태 업데이트
  recipient4.update!(status: :replied)
  
  # 양쪽에게 대화방 표시
  conversation.show_to!(user1.id)
  conversation.show_to!(user4.id)
  
  puts "✅ 사용자4 응답 완료"
  puts "  - 대화방 ID: #{conversation.id}"
  puts "  - 메시지 ID: #{message.id}"
else
  puts "❌ 사용자4가 수신자 목록에 없습니다."
end

# 6. 대화방 및 메시지 확인
puts "\n6. 대화방 상태 확인"
user1_conversations = Conversation.for_user(user1.id).not_deleted_for(user1.id)
user4_conversations = Conversation.for_user(user4.id).not_deleted_for(user4.id)

puts "  - 사용자1이 볼 수 있는 대화방: #{user1_conversations.count}개"
puts "  - 사용자4가 볼 수 있는 대화방: #{user4_conversations.count}개"

# 7. 읽음 처리 테스트
puts "\n7. 읽음 처리 테스트 (사용자1이 대화방 조회)"
if conversation
  unread_messages = conversation.messages.where(sender_id: user4.id, read: false)
  puts "  - 읽지 않은 메시지: #{unread_messages.count}개"
  
  # 읽음 처리
  unread_messages.update_all(read: true)
  puts "✅ 메시지 읽음 처리 완료"
end

# 8. 최종 상태 확인
puts "\n8. 최종 브로드캐스트 상태"
broadcast.reload
stats = {
  total: broadcast.broadcast_recipients.count,
  delivered: broadcast.broadcast_recipients.delivered.count,
  read: broadcast.broadcast_recipients.read.count,
  replied: broadcast.broadcast_recipients.replied.count
}

puts "  - 전체 수신자: #{stats[:total]}명"
puts "  - 전달됨: #{stats[:delivered]}명"
puts "  - 읽음: #{stats[:read]}명"
puts "  - 응답함: #{stats[:replied]}명"

puts "\n=== 브로드캐스트 흐름 테스트 완료 ==="