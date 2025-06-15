# Talkk API 서버 아키텍처 문서

## 개요
Talkk API는 Ruby on Rails 7.1.5.1 기반의 RESTful API 서버로, 음성 메시징 플랫폼의 백엔드를 담당합니다.

## 기술 스택
- **언어/프레임워크**: Ruby 3.3.0 / Rails 7.1.5.1
- **웹 서버**: Puma 6.6.0
- **데이터베이스**: PostgreSQL 16 (pgvector extension)
- **캐시/큐**: Valkey(Redis) 8
- **백그라운드 작업**: Sidekiq 7.3.9
- **배포**: Render (Singapore 리전)

## 디렉토리 구조

```
talk_api_open/
├── app/
│   ├── controllers/
│   │   ├── admin/          # 관리자 대시보드
│   │   ├── api/            # API 엔드포인트
│   │   │   └── v1/         # API 버전 1
│   │   └── concerns/       # 컨트롤러 공통 모듈
│   ├── models/             # ActiveRecord 모델
│   ├── services/           # 비즈니스 로직 서비스
│   ├── workers/            # Sidekiq 워커
│   ├── views/              # JSON 응답 템플릿
│   └── mailers/            # 이메일 발송
├── config/
│   ├── routes.rb           # 라우팅 설정
│   ├── database.yml        # DB 설정
│   ├── sidekiq.yml         # Sidekiq 설정
│   └── environments/       # 환경별 설정
├── db/
│   ├── migrate/            # 마이그레이션 파일
│   └── schema.rb           # DB 스키마
├── lib/                    # 라이브러리
├── spec/                   # RSpec 테스트
├── swagger/                # API 문서 (OpenAPI)
└── render.yaml             # Render 배포 설정
```

## 주요 모델

### 사용자 관련
- **User**: 사용자 정보 (전화번호 기반 인증)
- **PhoneVerification**: 전화번호 인증
- **UserDevice**: 사용자 디바이스 정보 (푸시 토큰)
- **Block**: 사용자 차단 관계

### 메시징 관련
- **Conversation**: 대화방
- **ConversationParticipant**: 대화 참여자
- **Message**: 메시지 (오디오 URL 포함)
- **AudioMessage**: 오디오 파일 메타데이터

### 브로드캐스트 관련
- **Broadcast**: 브로드캐스트 메시지
- **BroadcastRecipient**: 브로드캐스트 수신자
- **BroadcastReaction**: 브로드캐스트 반응

### 신고/관리
- **Report**: 신고 내역
- **UserBan**: 사용자 제재

## API 엔드포인트 (v1)

### 인증
- `POST /api/v1/auth/send_otp` - OTP 발송
- `POST /api/v1/auth/verify_otp` - OTP 검증
- `POST /api/v1/auth/refresh` - 토큰 갱신
- `DELETE /api/v1/auth/logout` - 로그아웃

### 사용자
- `GET /api/v1/users/profile` - 프로필 조회
- `PUT /api/v1/users/profile` - 프로필 수정
- `POST /api/v1/users/update_device` - 디바이스 정보 업데이트

### 대화
- `GET /api/v1/conversations` - 대화 목록
- `GET /api/v1/conversations/:id` - 대화 상세
- `POST /api/v1/conversations` - 대화 생성
- `DELETE /api/v1/conversations/:id` - 대화 삭제

### 메시지
- `GET /api/v1/conversations/:id/messages` - 메시지 목록
- `POST /api/v1/conversations/:id/messages` - 메시지 전송
- `PUT /api/v1/messages/:id/read` - 읽음 처리

### 브로드캐스트
- `GET /api/v1/broadcasts` - 내가 보낸 브로드캐스트
- `GET /api/v1/broadcasts/received` - 수신한 브로드캐스트
- `POST /api/v1/broadcasts` - 브로드캐스트 생성
- `PUT /api/v1/broadcasts/:id/mark_as_read` - 읽음 처리

### 차단/신고
- `POST /api/v1/blocks` - 사용자 차단
- `DELETE /api/v1/blocks/:id` - 차단 해제
- `POST /api/v1/reports` - 신고하기

## 주요 서비스

### BroadcastWorker
- 브로드캐스트 수신자 선택 알고리즘 실행
- 응답률, 상호작용, 선호도 기반 점수 계산
- 가중치 기반 샘플링으로 수신자 선택

### MessageCleanupWorker
- 6일 지난 메시지 자동 삭제
- 매일 실행 (cron)

### OtpService
- OTP 생성 및 발송
- SMS 제공업체 연동

## 환경 변수

```bash
# 필수 설정
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
SECRET_KEY_BASE=...
JWT_SECRET_KEY=...

# AWS S3 (오디오 저장)
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=ap-southeast-1
S3_BUCKET=talkk-audio

# 오디오 설정
AUDIO_URL_EXPIRY_DAYS=7
MAX_AUDIO_DURATION=30

# SMS 제공업체
SMS_PROVIDER_API_KEY=...

# 푸시 알림
EXPO_ACCESS_TOKEN=...
```

## 배포 구성 (Render)

### 서비스 구성
1. **웹 서비스** (talkk-api)
   - Ruby 3.3.0
   - 빌드: `bundle install`
   - 시작: `bundle exec puma -C config/puma.rb`

2. **백그라운드 워커** (talkk-sidekiq)
   - Sidekiq 워커
   - 시작: `bundle exec sidekiq`

3. **데이터베이스** (talkk-db)
   - PostgreSQL 16
   - pgvector extension

4. **캐시** (talkk-redis)
   - Valkey 8 (Redis 호환)

### 헬스체크
- 경로: `/health`
- 응답: `{ status: "ok", version: "..." }`

## 보안 고려사항

1. **인증**
   - JWT 토큰 기반 인증
   - 전화번호 OTP 검증

2. **권한**
   - 대화 참여자만 메시지 접근 가능
   - 차단된 사용자 필터링

3. **데이터 보호**
   - 오디오 URL 7일 후 만료
   - 메시지 6일 후 자동 삭제

4. **API 제한**
   - rack-attack으로 rate limiting
   - IP당 60 요청/분 제한

## 모니터링

- **Render Metrics**: 서버 리소스 모니터링
- **Sentry**: 에러 트래킹
- **Sidekiq Web UI**: 백그라운드 작업 모니터링

## CI/CD

- **GitHub Actions**: 자동 테스트 및 린팅
  - RSpec 테스트
  - RuboCop 코드 스타일
  - Brakeman 보안 스캔
- **Render**: main 브랜치 자동 배포
