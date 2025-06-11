# 브로드캐스트 API 테스트 가이드

## 1. 테스트 환경 설정

### 1.1 테스트 계정 준비
```bash
# Rails 콘솔에서 테스트 계정 생성
rails console
```

```ruby
# 테스트 계정 생성 (전화번호가 +8210으로 시작)
test_users = []
5.times do |i|
  user = User.create!(
    phone_number: "+8210000000#{i}",
    nickname: "TestUser#{i}",
    password: "password123",
    status: :active,
    gender: i.even? ? :male : :female,
    birth_year: 1990 + i,
    region: ["서울", "경기", "부산"][i % 3]
  )
  test_users << user
end

# 차단 관계 설정 (테스트용)
Block.create!(blocker: test_users[0], blocked: test_users[1])
```

### 1.2 인증 토큰 획득
```bash
# 로그인하여 JWT 토큰 획득
curl -X POST https://talkk-api.onrender.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+82100000000",
    "password": "password123"
  }'
```

## 2. API 엔드포인트 테스트

### 2.1 브로드캐스트 생성
```bash
# 오디오 파일을 Base64로 인코딩
base64 -i test_audio.mp3 -o audio_base64.txt

# 브로드캐스트 생성
curl -X POST https://talkk-api.onrender.com/api/v1/broadcasts \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "broadcast": {
      "audio_data": "data:audio/mp3;base64,YOUR_BASE64_AUDIO",
      "duration": 15
    }
  }'
```

### 2.2 수신한 브로드캐스트 조회
```bash
# 내가 받은 브로드캐스트 목록
curl -X GET https://talkk-api.onrender.com/api/v1/broadcasts/received \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 2.3 브로드캐스트 읽음 처리
```bash
# 브로드캐스트를 읽음으로 표시
curl -X PUT https://talkk-api.onrender.com/api/v1/broadcasts/BROADCAST_ID/mark_as_read \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 2.4 브로드캐스트 답장
```bash
# 브로드캐스트에 답장
curl -X POST https://talkk-api.onrender.com/api/v1/broadcasts/BROADCAST_ID/reply \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "audio_data": "data:audio/mp3;base64,YOUR_BASE64_AUDIO",
      "duration": 10
    }
  }'
```

## 3. 자동화 테스트 스크립트

### 3.1 RSpec 테스트 실행
```bash
# 전체 브로드캐스트 테스트 실행
bundle exec rspec spec/requests/api/v1/broadcasts_spec.rb

# 특정 테스트만 실행
bundle exec rspec spec/requests/api/v1/broadcasts_spec.rb:LINE_NUMBER

# 브로드캐스트 워커 테스트
bundle exec rspec spec/workers/broadcast_worker_spec.rb
```

### 3.2 테스트 커버리지 확인
```bash
# SimpleCov로 커버리지 측정
COVERAGE=true bundle exec rspec

# 커버리지 리포트 확인
open coverage/index.html
```

## 4. 시나리오 기반 테스트

### 4.1 기본 브로드캐스트 플로우
1. 사용자 A가 브로드캐스트 생성
2. 시스템이 자동으로 수신자 선택 (B, C, D)
3. 사용자 B가 수신 브로드캐스트 목록 조회
4. 사용자 B가 브로드캐스트 재생 (자동 읽음 처리)
5. 사용자 B가 답장 전송
6. 사용자 A가 답장 확인

### 4.2 차단 사용자 테스트
1. 사용자 A가 사용자 B를 차단
2. 사용자 B가 브로드캐스트 생성
3. 사용자 A가 수신자에서 제외되는지 확인

### 4.3 다양성 테스트
1. 사용자 A가 브로드캐스트 생성
2. 24시간 이내에 다시 브로드캐스트 생성
3. 수신자 목록이 다양하게 선택되는지 확인

## 5. 성능 테스트

### 5.1 부하 테스트
```ruby
# Rails 콘솔에서 대량 브로드캐스트 생성
100.times do
  BroadcastWorker.perform_async(
    user.id,
    "test_audio_url",
    15,
    50  # 수신자 수
  )
end
```

### 5.2 응답 시간 측정
```bash
# Apache Bench로 부하 테스트
ab -n 100 -c 10 \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://talkk-api.onrender.com/api/v1/broadcasts/received
```

## 6. 디버깅 팁

### 6.1 로그 확인
```bash
# Sidekiq 로그 확인 (브로드캐스트 워커)
heroku logs --tail --app talkk-api | grep BroadcastWorker

# Rails 로그 확인
tail -f log/development.log | grep "차단"
```

### 6.2 Redis 모니터링
```bash
# Redis CLI로 캐시 확인
redis-cli
> KEYS broadcast:*
> GET broadcast:recipients:USER_ID
```

### 6.3 데이터베이스 쿼리
```sql
-- 최근 브로드캐스트 수신자 통계
SELECT 
  recipient_id,
  COUNT(*) as receive_count,
  SUM(CASE WHEN status = 'replied' THEN 1 ELSE 0 END) as reply_count
FROM broadcast_recipients
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY recipient_id
ORDER BY receive_count DESC;
```

## 7. 문제 해결

### 7.1 수신자가 선택되지 않는 경우
- 활성 사용자 수 확인
- 차단 관계 확인
- 최근 로그인 시간 확인

### 7.2 브로드캐스트가 전달되지 않는 경우
- Sidekiq 큐 상태 확인
- 워커 에러 로그 확인
- Redis 연결 상태 확인

### 7.3 API 응답이 느린 경우
- N+1 쿼리 확인
- 인덱스 누락 확인
- 캐시 히트율 확인
