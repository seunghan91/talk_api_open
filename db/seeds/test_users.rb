# 테스트용 사용자 계정 시드 데이터
puts "Creating test users..."

# 기존 테스트 사용자 삭제 (개발 환경에서만)
if Rails.env.development?
  User.where(phone_number: [ '01011111111', '01022222222', '01033333333', '01044444444', '01055555555' ]).destroy_all
end

# 앱의 테스트 계정과 일치하는 사용자 생성
# 테스트 사용자 1 - A - 김철수 (브로드캐스터)
user1 = User.create!(
  password: 'password',
  password_confirmation: 'password',
  phone_number: '01011111111',
  nickname: 'A - 김철수',
  gender: 1, # male
  push_enabled: true,
  message_push_enabled: true,
  broadcast_push_enabled: true
)

# 테스트 사용자 2 - B - 이영희 (수신자)
user2 = User.create!(
  password: 'password',
  password_confirmation: 'password',
  phone_number: '01022222222',
  nickname: 'B - 이영희',
  gender: 2, # female
  push_enabled: true,
  message_push_enabled: true,
  broadcast_push_enabled: true
)

# 테스트 사용자 3 - C - 박지민 (일반 사용자)
user3 = User.create!(
  password: 'password',
  password_confirmation: 'password',
  phone_number: '01033333333',
  nickname: 'C - 박지민',
  gender: 1, # male
  push_enabled: true,
  message_push_enabled: false, # 메시지 알림 비활성화로 테스트
  broadcast_push_enabled: true
)

# 테스트 사용자 4 - D - 최수진 (추가 테스터)
user4 = User.create!(
  password: 'password',
  password_confirmation: 'password',
  phone_number: '01044444444',
  nickname: 'D - 최수진',
  gender: 2, # female
  push_enabled: true,
  message_push_enabled: true,
  broadcast_push_enabled: true
)

# 테스트 사용자 5 - E - 정민준 (추가 테스터)
user5 = User.create!(
  password: 'password',
  password_confirmation: 'password',
  phone_number: '01055555555',
  nickname: 'E - 정민준',
  gender: 1, # male
  push_enabled: true,
  message_push_enabled: true,
  broadcast_push_enabled: true
)

# 팔로우 관계는 현재 구현되지 않음 - 추후 구현 예정
puts "Follow relationships will be implemented later..."

puts "Test users created successfully!"
puts "="*50
puts "테스트 계정 정보 (앱과 동일):"
puts "1. A - 김철수: 010-1111-1111 / password"
puts "   - 역할: 브로드캐스팅 송신 테스트"
puts ""
puts "2. B - 이영희: 010-2222-2222 / password"
puts "   - 역할: 브로드캐스팅 수신 테스트"
puts ""
puts "3. C - 박지민: 010-3333-3333 / password"
puts "   - 역할: 메시지 알림 비활성화 테스트"
puts ""
puts "4. D - 최수진: 010-4444-4444 / password"
puts "   - 역할: 추가 테스터"
puts ""
puts "5. E - 정민준: 010-5555-5555 / password"
puts "   - 역할: 추가 테스터"
puts "="*50
puts "💡 이 계정들은 앱의 로그인 화면에서 버튼으로 바로 선택 가능합니다!"
