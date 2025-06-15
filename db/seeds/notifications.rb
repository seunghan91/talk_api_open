# 테스트 알림 데이터 생성
user = User.first || User.create!(
  nickname: 'TestUser', 
  phone_number: '01011111111', 
  verified: true,
  password: 'password123'
)

puts "Creating test notifications for user: #{user.nickname}"

10.times do |i|
  Notification.create!(
    user: user,
    notification_type: ['message', 'broadcast', 'system'].sample,
    title: "테스트 알림 #{i + 1}",
    body: "이것은 테스트 알림입니다. 알림 번호: #{i + 1}",
    read: [true, false].sample,
    metadata: { test: true, index: i + 1 }
  )
end

puts "Created #{Notification.count} test notifications" 