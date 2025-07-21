# 브로드캐스트 수신자 선택 알고리즘 상세 설명서

## 1. 알고리즘 개요

Talkk의 브로드캐스트 수신자 선택 알고리즘은 다음 목표를 달성하기 위해 설계되었습니다:

- **관련성**: 브로드캐스트에 관심을 가질 가능성이 높은 사용자 선택
- **공정성**: 모든 활성 사용자에게 브로드캐스트 수신 기회 제공
- **다양성**: 동일한 사용자들에게만 반복 전송 방지
- **효율성**: 높은 응답률과 참여율 달성

## 2. 알고리즘 단계별 설명

### 2.1 기본 필터링 단계

```ruby
# 1. 차단된 사용자 제외
blocked_user_ids = get_blocked_user_ids(sender)
# - 양방향 차단 관계 확인 (내가 차단 OR 나를 차단)

# 2. 기본 조건 필터링
base_query = User.where.not(id: [sender.id] + blocked_user_ids)
                 .where(status: :active)           # 활성 계정만
                 .where.not(phone_number: nil)     # 전화번호 필수
```

### 2.2 테스트 계정 우선 처리

```ruby
# 테스트 계정(+8210으로 시작)끼리 우선 매칭
if sender.phone_number&.start_with?('+8210')
  test_users = base_query.where("phone_number LIKE ?", '+8210%')
  # 충분한 테스트 계정이 있으면 그들 중에서만 선택
end
```

### 2.3 활동성 기반 필터링

```ruby
# 최근 30일 이내 로그인한 사용자
recent_active_users = base_query.where("last_sign_in_at > ?", 30.days.ago)

# 24시간 이내 브로드캐스트 수신자 일부 제외 (다양성 확보)
recent_recipients = BroadcastRecipient.where("created_at > ?", 24.hours.ago)
                                     .pluck(:recipient_id)
# 50%만 제외하여 완전 차단 방지
excluded_recent = recent_recipients.sample(recent_recipients.size / 2)
```

### 2.4 점수 계산

#### 2.4.1 응답률 점수 (25%)
```ruby
def calculate_response_scores(sender, user_ids)
  # 과거 브로드캐스트에 대한 응답 비율 계산
  # replied 상태인 브로드캐스트 수 / 전체 수신 브로드캐스트 수
  # 송신자와의 과거 상호작용도 가산점
end
```

#### 2.4.2 상호작용 점수 (25%)
```ruby
def calculate_interaction_scores(sender, user_ids)
  # 최근 30일간 대화 활동 측정
  # - 메시지 송수신 빈도
  # - 대화 지속 시간
  # - 양방향 대화 여부
end
```

#### 2.4.3 선호도 점수 (20%)
```ruby
def calculate_preference_scores(sender, user_ids)
  # 인구통계학적 매칭
  # - 성별: 이성 선호 시 가산점
  # - 연령대: 유사 연령대 가산점 (±5세)
  # - 지역: 같은 지역 가산점
end
```

#### 2.4.4 활동도 점수 (30%)
```ruby
def calculate_activity_scores(user_ids)
  # 최근 활동 빈도
  # - 마지막 로그인 시간 (최근일수록 높은 점수)
  # - 일일 평균 사용 시간
  # - 최근 브로드캐스트 수신자인 경우 50% 감점
end
```

### 2.5 최종 선택

```ruby
# 1. 종합 점수 계산
final_score = (response_score * 0.25) + 
              (interaction_score * 0.25) +
              (preference_score * 0.20) +
              (activity_score * 0.30)

# 2. 확률적 선택
# - 상위 20%: 무조건 포함
# - 나머지 80%: 점수 기반 확률적 선택 (weighted sampling)
```

## 3. 점수 계산 예시

### 사용자 A (높은 점수)
- 응답률: 80% → 0.8 × 0.25 = 0.20
- 상호작용: 활발함 → 0.9 × 0.25 = 0.225
- 선호도: 매칭됨 → 0.7 × 0.20 = 0.14
- 활동도: 1시간 전 로그인 → 1.0 × 0.30 = 0.30
- **총점: 0.865**

### 사용자 B (낮은 점수)
- 응답률: 20% → 0.2 × 0.25 = 0.05
- 상호작용: 적음 → 0.3 × 0.25 = 0.075
- 선호도: 불일치 → 0.2 × 0.20 = 0.04
- 활동도: 20일 전 로그인 → 0.3 × 0.30 = 0.09
- **총점: 0.255**

## 4. 특별 규칙

### 4.1 차단 사용자 처리
- 양방향 차단 확인 (내가 차단 OR 나를 차단)
- 차단 로그 기록으로 디버깅 용이

### 4.2 최소 수신자 보장
```ruby
if selected_users.size < recipient_count
  # 부족한 경우 조건을 완화하여 추가 선택
  # 1차: 활동 기간을 30일 → 60일로 확대
  # 2차: 랜덤 선택으로 보충
end
```

### 4.3 최대 수신자 제한
- 한 번에 최대 100명까지만 선택 가능
- 시스템 부하 방지 및 스팸 방지

## 5. 성능 최적화

### 5.1 쿼리 최적화
```sql
-- 복합 인덱스 활용
CREATE INDEX idx_users_activity ON users(status, last_sign_in_at);
CREATE INDEX idx_broadcast_recipients_recent ON broadcast_recipients(recipient_id, created_at);
```

### 5.2 캐싱 전략
- 사용자 점수 캐싱 (Redis, TTL: 1시간)
- 차단 관계 캐싱 (Redis, TTL: 10분)

### 5.3 배치 처리
- 대량 BroadcastRecipient 생성 시 `insert_all` 사용
- 트랜잭션으로 일관성 보장

## 6. 모니터링 및 튜닝

### 6.1 주요 지표
- 평균 응답률 (목표: 30% 이상)
- 수신자 다양성 지수
- 알고리즘 실행 시간 (목표: 1초 이내)

### 6.2 A/B 테스트
- 가중치 조정 실험
- 새로운 점수 요소 추가 테스트

### 6.3 피드백 루프
- 실제 응답률 데이터로 가중치 자동 조정
- 머신러닝 모델 도입 준비
