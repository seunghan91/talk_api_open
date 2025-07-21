# Voice Broadcasting App Flow Guide

## 📱 앱 개요
Talk 앱은 랜덤한 사용자들에게 음성 메시지를 브로드캐스팅하고, 응답을 받아 대화를 나눌 수 있는 음성 기반 소셜 앱입니다.

## 🔄 전체 흐름

### 1. 앱 시작 및 로그인
- **API**: `POST /api/auth/login`
- **필요 정보**: 전화번호, 비밀번호
- **응답**: JWT 토큰 발급

### 2. 음성 녹음 및 재생
- 클라이언트에서 음성 녹음 기능 구현
- 녹음된 음성을 재생하여 확인 가능

### 3. 브로드캐스트 전송
- **API**: `POST /api/broadcasts`
- **요청 데이터**:
  ```javascript
  {
    broadcast: {
      audio: [음성파일],
      text: "안녕하세요!",
      recipient_count: 5
    }
  }
  ```
- **처리 과정**:
  1. `BroadcastsController#create`에서 요청 수신
  2. `Broadcasts::CreateService`로 브로드캐스트 생성
  3. `BroadcastWorker`가 비동기로 수신자 선택 및 전송

### 4. 수신자 선택 및 전송
- **수신자 선택**: `RecipientSelectionService`
- **선택 전략**:
  - 랜덤 선택
  - 활동성 기반 선택
  - 관계 기반 선택
- **결과**: A, B, C 사용자에게 브로드캐스트 전달

### 5. 브로드캐스트 수신 및 응답
- **수신자 상태**:
  - A: 미응답 (delivered)
  - B: 미응답 (delivered)
  - C: 응답 (replied)
- **응답 API**: `POST /api/broadcasts/:id/reply`
- **처리**:
  1. `BroadcastRecipient` 상태를 'replied'로 업데이트
  2. 대화방 자동 생성
  3. 양쪽 사용자에게 대화방 표시

### 6. 대화방 생성 및 메시지 표시
- **대화방 생성**: `Conversation.find_or_create_conversation`
- **표시 내용**:
  - 사용자1이 보낸 브로드캐스트 메시지
  - C가 응답한 음성 메시지
- **가시성**: 응답 시 양쪽 모두에게 대화방 표시

### 7. 메시지 읽음 처리
- **API**: `GET /api/conversations/:id`
- **자동 처리**: 대화방 조회 시 상대방 메시지 자동 읽음 처리
- **읽지 않은 메시지 수 확인**: `GET /api/conversations/:id/unread_count`

### 8. 자유로운 대화
- **API**: `POST /api/conversations/:id/send_message`
- **메시지 타입**: 음성, 텍스트, 이미지
- **실시간 알림**: `PushNotificationWorker`를 통한 푸시 알림

## 📊 상태 관리

### BroadcastRecipient 상태
- `delivered`: 전달됨
- `read`: 읽음
- `replied`: 응답함

### Message 읽음 상태
- `read: false`: 읽지 않음
- `read: true`: 읽음

### Conversation 가시성
- `deleted_by_a`: user_a에게 숨김
- `deleted_by_b`: user_b에게 숨김

## 🔍 브로드캐스트 상세 조회
- **API**: `GET /api/broadcasts/:id`
- **제공 정보**:
  - 수신자 목록 및 상태
  - 응답 통계 (전달됨/읽음/응답함)

## 📋 주요 모델 관계
```
User
  ├── has_many :broadcasts (발송한 브로드캐스트)
  ├── has_many :broadcast_recipients (수신한 브로드캐스트)
  └── has_many :conversations (참여한 대화)

Broadcast
  ├── belongs_to :user (발신자)
  └── has_many :broadcast_recipients (수신자들)

BroadcastRecipient
  ├── belongs_to :broadcast
  └── belongs_to :user (수신자)

Conversation
  ├── belongs_to :user_a
  ├── belongs_to :user_b
  └── has_many :messages

Message
  ├── belongs_to :conversation
  ├── belongs_to :sender
  └── belongs_to :broadcast (optional)
```

## 🧪 테스트 방법

### 1. 시드 데이터 생성
```bash
bundle exec rails db:seed
```

### 2. 테스트 스크립트 실행
```bash
bundle exec rails runner scripts/test_broadcast_flow.rb
```

### 3. 테스트 시나리오
1. 테스트사용자1이 브로드캐스트 전송
2. 테스트사용자2, 3, 4가 수신
3. 테스트사용자4가 응답
4. 대화방 생성 및 메시지 교환
5. 읽음 처리 확인

## 🚀 성능 최적화
- 메시지 캐싱 (30초)
- 대화 목록 캐싱
- 비동기 브로드캐스트 처리 (Sidekiq)
- 인덱스 최적화

## 📱 클라이언트 구현 가이드
See [API_DOCUMENTATION.md](API_DOCUMENTATION.md) for details