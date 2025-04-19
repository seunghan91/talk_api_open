# Talkk API

음성 기반 소셜 미디어 플랫폼 Talkk의 백엔드 API

## 최근 업데이트 (2025-04-19)

### 1. 사용자 프로필 개선 및 관리 시스템 보강

1. **사용자 프로필 필드 확장**
   - 연령대(`age_group`) 및 지역(`region`) 필드 추가
   - 현재: 초기 유저들에게는 필수값 아님 (인덱스와 구조만 미리 구축)
   - 향후: 사용자 수가 충분히 확보되면 필터링 알고리즘에 활용 예정

2. **신고 및 차단 시스템 강화**
   - 단계적 제재 시스템 구현 (신고 유형별 임계값 기반)
     - 성별 위장: 1회 발생 시 즉시 제재 (One-strike policy)
     - 불건전 콘텐츠: 3회 누적 시 제재
     - 일반 신고: 5회 누적 시 제재
   - 계정 정지 기록 관리 및 자동 해제 기능 구현
   - 관리자 신고 처리 대시보드 구현

3. **관리자 대시보드 신규 개발**
   - 종합 통계 현황 모니터링
   - 신고 내역 조회 및 처리 인터페이스
   - 사용자 관리 및 계정 정지/해제 기능
   - 신고 자동화 처리 시스템과 연동

### 2. 오디오 시스템 개선 사항

1. **오디오 URL 유효 기간 관리 개선**
   - 기존: 기본 URL 서명 만료 시간이 짧아 재생 실패 발생
   - 개선: 오디오 URL 유효 기간을 기본 7일로 설정하고 환경 변수(`AUDIO_URL_EXPIRY_DAYS`)로 관리자가 조절 가능하도록 구현
   - 영향: 비동기 소통 목적에 맞게 오디오 콘텐츠 자체 만료 시간(expired_at)과 일관되게 관리

2. **푸시 알림 시스템 안정화**
   - 기존: 메시지 푸시 알림 누락 발생
   - 개선: Sidekiq 작업 실패 시 자동 재시도 및 로깅 강화로 알림 전달률 향상
   - 주요 변경: 작업 재시도 정책 최적화 (최대 5회, 점진적 대기시간 증가)

## 프로젝트 개요

Talkk는 음성 기반 소셜 네트워킹 플랫폼으로, 사용자들이 짧은 음성 메시지를 브로드캐스팅하고 1:1 대화를 나눌 수 있는 서비스입니다. 텍스트 대신 음성을 사용하여 더 인간적이고 감정이 담긴 소통을 가능하게 합니다.

## 주요 기능

### 회원 관리
- 휴대전화번호 기반 회원가입 및 인증
- SMS 인증 코드를 통한 본인 확인
- 익명 닉네임 및 식별코드 자동 부여
- 성별 정보 선택적 제공

### 음성 브로드캐스팅
- 1~30초 길이의 음성 메시지 녹음 및 브로드캐스팅
- 최대 6일간 저장 후 자동 삭제 (expired_at 속성으로 관리)
- 메인 화면에서 최신순으로 브로드캐스트 목록 표시
- 브로드캐스트에 대한 답장으로 1:1 대화 시작 가능

### 1:1 대화
- 브로드캐스트 답장으로 생성되는 1:1 대화방
- 음성 메시지를 통한 대화 지속
- 대화방 즐겨찾기, 삭제 기능
- 사용자 신고 및 차단 기능

### 추가 기능
- 메아리(Echo) 기능: 다수 사용자에게 브로드캐스트
- 알림 설정 (푸시, 진동, 소리)
- 자동재생 설정 (대화방 진입 시 최신 메시지 자동 재생)

## 기술 스택

- Ruby on Rails 7.2.2
- PostgreSQL
- Redis & Sidekiq (비동기 작업 및 작업 스케줄링)
- Active Storage (음성 파일 저장)
- JWT (인증)
- RailsAdmin (관리자 페이지)

## 시작하기

### 사전 요구사항
- Ruby 3.1.0
- PostgreSQL
- Redis

### 설치
```bash
# 저장소 클론
git clone https://github.com/yourusername/talk_api_open.git
cd talk_api_open

# 의존성 설치
bundle install

# 데이터베이스 설정
bin/rails db:create db:migrate db:seed

# 서버 실행
bin/rails server
```

### 테스트 계정
시스템에는 다음과 같은 테스트 계정이 제공됩니다:

| 계정 | 전화번호 | 비밀번호 |
|------|---------|---------|
| A - 김철수 | 01011111111 | test1234 |
| B - 이영희 | 01022222222 | test1234 |
| C - 박지민 | 01033333333 | test1234 |
| D - 최수진 | 01044444444 | test1234 |
| E - 정민준 | 01055555555 | test1234 |
| 관리자 | 01099999999 | admin123 |

이 계정들을 이용해 음성 메시지 전송 및 브로드캐스트 기능을 테스트할 수 있습니다.

## 자동화된 테스트

Talkk API는 RSpec을 사용하여 자동화된 테스트를 제공합니다. 

### 테스트 설정
```bash
# RSpec 테스트 실행
bundle exec rspec

# 특정 디렉토리의 테스트 실행
bundle exec rspec spec/requests/api/v1/

# 특정 파일의 테스트 실행
bundle exec rspec spec/requests/api/v1/auth_spec.rb

# 특정 라인의 테스트 실행
bundle exec rspec spec/requests/api/v1/users_spec.rb:10-20
```

### 테스트 구조
- `spec/factories/`: 모델의 팩토리 정의
- `spec/requests/api/v1/`: API v1 엔드포인트 테스트
- `spec/models/`: 모델 단위 테스트
- `spec/support/`: 테스트 헬퍼 및 공통 기능

### Swagger 문서 생성
```bash
# Swagger 문서 생성
RAILS_ENV=test bundle exec rake rswag:specs:swaggerize

# 생성된 문서 확인
# 브라우저에서 http://localhost:3000/api-docs 접속
```

## 신고 및 차단 시스템

Talkk API는 사용자 보호를 위한 강력한 신고 및 차단 시스템을 제공합니다.

### 신고 유형 및 처리 정책

Talkk 시스템은 다음과 같은 신고 유형별 정책을 적용합니다:

| 신고 유형 | 임계값 | 제재 조치 |
|------------|--------|------------|
| 성별 위장 | 1회 | 즉시 1일 정지 (One-strike) |
| 불건전 콘텐츠 | 3회 | 3일 정지 |
| 일반 신고 | 5회 | 1일 정지 |

### 계정 정지 관리

- 정지 기간이 만료된 계정은 매일 `ExpiredSuspensionWorker`에 의해 자동으로 정상화됩니다.
- 사용자에게는 정지 및 해제 시 알림이 자동 발송됩니다.
- 정지 내역은 `UserSuspension` 모델에 기록됩니다.

### 신고 API 사용법

```bash
# 사용자 신고하기
POST /api/v1/reports
{
  "report": {
    "reported_id": 123,                 # 신고할 사용자 ID
    "report_type": "user",           # 신고 유형 (user, broadcast, message)
    "reason": "gender_impersonation" # 신고 사유
  }
}
```

### 신고 자동화 처리

`ReportHandlerService` 클래스는 신고 내역을 자동으로 처리합니다:

```ruby
# 신고 처리 예시
ReportHandlerService.process_report(report)
```

## 관리자 대시보드

Talkk API는 포괄적인 관리자 대시보드를 제공하여 신고 및 사용자 관리를 용이하게 합니다.

### 접근 방법

관리자 대시보드는 다음 경로로 접근할 수 있습니다:

```
http://[서버 주소]/admin
```

관리자 계정으로 로그인해야 접근이 가능합니다.

### 주요 기능

1. **기본 대시보드**
   - 신고 현황, 계정 정지, 사용자, 브로드캐스트 통계 요약
   - 최근 신고 및 정지 내역 표시
   
2. **신고 관리**
   - 신고 목록 조회 및 필터링
   - 신고 처리 및 거부 기능
   
3. **사용자 관리**
   - 사용자 목록 조회 및 필터링
   - 사용자 정지 및 해제 기능
   - 정지 기간 및 사유 지정

### 실행 예시

```bash
# 관리자 대시보드 실행
# 실행 전 Rails 서버가 작동 중이어야 합니다
bin/rails server

# 처리 정지 기간 만료 작업 실행 (수동)
bin/rails runner 'ExpiredSuspensionWorker.new.perform'
```

## 음성 메시지 처리 과정

Talkk API는 음성 메시지를 다음 단계로 처리합니다:

1. **음성 파일 업로드**:
   - 클라이언트에서 녹음된 음성 파일(보통 m4a 포맷)을 multipart/form-data로 서버에 전송
   - 서버는 Active Storage를 통해 음성 파일을 저장

2. **메시지 생성**:
   - 메시지 객체 생성 (대화방 ID, 발신자 ID 포함)
   - 음성 파일을 메시지에 첨부 (voice_file.attach)
   - 메시지 타입은 기본적으로 'voice'로 설정

3. **푸시 알림 처리**:
   - 메시지 생성 후 수신자에게 푸시 알림 전송
   - Sidekiq을 통한 비동기 처리로 애플리케이션 성능 향상

4. **메시지 만료 처리**:
   - 브로드캐스트 메시지는 6일 후 자동 만료 (expired_at 설정)
   - 만료된 메시지는 더 이상 앱에 표시되지 않음

## 시드 데이터

Talkk API는 개발 및 테스트 목적으로 시드 데이터를 제공합니다. 시드 데이터에는 테스트 계정, 대화방, 브로드캐스트, 메시지 등이 포함됩니다.

### 시드 데이터 생성
```bash
# 시드 데이터 생성
bin/rails db:seed

# 특정 환경에서 시드 데이터 생성
RAILS_ENV=development bin/rails db:seed
```

### 시드 데이터 내용
- 6개의 테스트 계정 (일반 사용자 5명, 관리자 1명)
- 복수의 대화방
- 샘플 브로드캐스트 및 메시지 (오디오 샘플 포함)
- 지갑 및 거래 내역
- 알림 예제

### 오디오 샘플
시드 데이터는 `public/audio_samples` 디렉토리의 오디오 샘플 파일을 사용합니다:
- sample_audio.wav (브로드캐스트용)
- sample_audio1..wav (메시지 응답용)
- sample_audio2.wav (일반 메시지용)

API 서버는 환경에 따라 적절한 URL로 오디오 파일을 제공합니다.

## 관리자 페이지

Talkk API는 RailsAdmin을 사용하여 관리자 페이지를 제공합니다. 관리자 페이지에서는 사용자, 브로드캐스트, 대화, 메시지, 신고, 차단 등의 데이터를 관리할 수 있습니다.

### 접속 방법
- URL: `/admin` (예: http://localhost:3000/admin)
- 사용자 이름: `admin`
- 비밀번호: `admin2024`

### 주요 관리 기능

#### 사용자(User) 관리
- 목록 보기: ID, 닉네임, 전화번호, 성별, 가입일, 상태 등 표시
- 상세 보기: 프로필 정보, 푸시 토큰, 신고 내역 등 확인
- 커스텀 액션: 계정 정지/활성화, 영구 차단, 신고 내역 초기화

#### 브로드캐스트(Broadcast) 관리
- 목록 보기: ID, 작성자, 생성일, 만료일, 만료 상태 등 표시
- 상세 보기: 음성 파일, 작성자 정보 등 확인
- 커스텀 액션: 만료일 연장

#### 대화(Conversation) 관리
- 목록 보기: 대화 참여자, 생성일, 메시지 수 등 표시
- 상세 보기: 대화에 포함된 메시지 목록 확인

#### 메시지(Message) 관리
- 목록 보기: 대화 ID, 발신자, 생성일, 음성 파일, 읽음 상태 등 표시
- 상세 보기: 메시지 상세 정보 확인
- 커스텀 액션: 읽음/읽지 않음 상태 변경

#### 신고(Report) 관리
- 목록 보기: 신고자, 피신고자, 신고 사유, 상태 등 표시
- 상세 보기: 신고 상세 정보 확인
- 커스텀 액션: 처리 상태 변경, 신고된 사용자 정지

#### 차단(Block) 관리
- 목록 보기: 차단한 사용자, 차단된 사용자, 차단 일시 등 표시
- 상세 보기: 차단 상세 정보 확인

## API 엔드포인트

주요 API 엔드포인트는 다음과 같습니다:

### 인증 관련 (Auth)
- `POST /api/v1/auth/request_code`: 인증 코드 요청
- `POST /api/v1/auth/verify_code`: 인증 코드 확인
- `POST /api/v1/auth/register`: 회원가입
- `POST /api/v1/auth/login`: 로그인

### 사용자 관련 (Users)
- `GET /api/v1/users/profile`: 사용자 프로필 조회
- `GET /api/v1/users/me`: 현재 로그인한 사용자 정보 조회
- `POST /api/v1/users/change_nickname`: 닉네임 변경
- `GET /api/v1/users/generate_random_nickname`: 랜덤 닉네임 생성
- `POST /api/v1/users/update_profile`: 프로필 정보 업데이트
- `GET /api/v1/users/notification_settings`: 알림 설정 조회
- `PATCH /api/v1/users/notification_settings`: 알림 설정 업데이트

### 브로드캐스트 관련 (Broadcasts)
- `GET /api/v1/broadcasts`: 브로드캐스트 목록 조회
- `POST /api/v1/broadcasts`: 브로드캐스트 생성
- `GET /api/v1/broadcasts/:id`: 브로드캐스트 조회
- `POST /api/v1/broadcasts/:id/reply`: 브로드캐스트에 답장
- `GET /api/v1/broadcasts/example_broadcast`: 샘플 브로드캐스트 조회

### 대화 관련 (Conversations)
- `GET /api/v1/conversations`: 대화 목록 조회
- `GET /api/v1/conversations/:id`: 대화 조회
- `POST /api/v1/conversations/:id/send_message`: 메시지 전송
- `POST /api/v1/conversations/:id/favorite`: 대화 즐겨찾기 추가
- `POST /api/v1/conversations/:id/unfavorite`: 대화 즐겨찾기 제거
- `DELETE /api/v1/conversations/:id`: 대화 삭제

### 알림 관련 (Notifications)
- `GET /api/v1/notifications`: 알림 목록 조회
- `GET /api/v1/notifications/:id`: 알림 조회
- `POST /api/v1/notifications/:id/mark_as_read`: 알림 읽음 표시
- `POST /api/v1/notifications/mark_all_as_read`: 모든 알림 읽음 표시
- `POST /api/v1/notifications/update_push_token`: 푸시 토큰 업데이트

### 지갑 관련 (Wallets)
- `GET /api/v1/wallets`: 지갑 정보 조회
- `GET /api/v1/wallets/transactions`: 거래 내역 조회
- `POST /api/v1/wallets/deposit`: 지갑 충전

자세한 API 문서는 Swagger UI(`/api-docs`)에서 확인할 수 있습니다.

## API 개발 가이드라인

### 1. API 버전 관리

모든 API는 명확한 버전 관리 전략을 사용합니다:

- 모든 API 요청은 `/api/v1/*` 형식의 경로를 사용해야 합니다.
- 각 버전은 별도의 네임스페이스로 구성됩니다:
  - `/api/v1/*` → `Api::V1::*` 컨트롤러
  - `/api/v2/*` → `Api::V2::*` 컨트롤러 (향후 구현)

레거시 API(버전이 없는 `/api/*` 엔드포인트)는 호환성을 위해 유지되지만, 
신규 개발 시에는 반드시 버전이 있는 API를 사용해야 합니다.

### 2. 컨트롤러 구조

컨트롤러는 다음과 같은 구조를 따릅니다:

```
app/controllers/
  ├── api/
  │   ├── base_controller.rb
  │   ├── v1/
  │   │   ├── base_controller.rb
  │   │   ├── users_controller.rb
  │   │   ├── auth/
  │   │   │   └── auth_controller.rb
  │   │   └── ...
  │   └── ...
  └── ...
```

- 모든 API v1 컨트롤러는 `Api::V1::BaseController`를 상속받습니다.
- 인증 관련 로직은 `Api::V1::Auth` 네임스페이스에 위치합니다.

### 3. API 문서화

API 문서는 OpenAPI(Swagger) 규격을 따릅니다:

- API 문서는 `/api-docs` 경로에서 접근할 수 있습니다.
- 새로운 API를 추가할 때는 컨트롤러에 Swagger 주석을 추가해야 합니다:

```ruby
# @swagger
# /api/v1/users/{id}:
#   get:
#     summary: 사용자 정보 조회
#     tags: [사용자]
#     parameters:
#       - name: id
#         in: path
#         required: true
#         type: integer
#     responses:
#       200:
#         description: 성공적으로 사용자 정보 반환
```

### 4. 오류 처리

일관된 오류 응답 형식을 사용합니다:

```json
{
  "error": "오류 메시지",
  "code": "오류_코드" // 선택적
}
```

모든 예외는 적절한 HTTP 상태 코드와 함께 처리되어야 합니다:
- 400: 잘못된 요청
- 401: 인증 실패
- 403: 권한 없음
- 404: 리소스 없음
- 422: 유효성 검사 오류
- 500: 서버 오류

### 5. 로깅

모든 API 요청과 응답은 적절히 로깅되어야 합니다:

- 요청 시: 메서드, 경로, 파라미터
- 응답 시: 상태 코드, 처리 시간
- 오류 발생 시: 상세 오류 정보와 스택 트레이스

로그 레벨을 적절하게 사용하세요:
- INFO: 일반적인 요청/응답 정보
- WARN: 잠재적 문제
- ERROR: 오류 상황

### 6. API 변경 관리

API를 변경할 때는 다음 사항을 고려해야 합니다:

1. 하위 호환성을 유지하세요. 기존 클라이언트가 중단되지 않아야 합니다.
2. 파괴적인 변경이 필요한 경우, 새로운 API 버전을 만드세요.
3. 제거 예정인 API는 명확히 문서화하고 충분한 마이그레이션 기간을 제공하세요.

### 7. 테스트

모든 API 엔드포인트는 테스트해야 합니다:

```bash
# 테스트 실행
bundle exec rspec spec/requests/api/v1/

# API 문서 생성
RAILS_ENV=test bundle exec rake rswag:specs:swaggerize
```

## 최근 변경사항 및 개선 내용

### 1. 닉네임 변경 기능 개선
- API 경로 충돌 문제 해결: API v1과 레거시 경로 모두 정상 작동
- 컨트롤러 액션 확인 및 추가: 누락된 액션 추가
- 오류 메시지 개선

### 2. 자동화된 테스트 환경 구성
- RSpec 설정 및 팩토리 구성
- 테스트 헬퍼 및 지원 클래스 추가
- API 엔드포인트 테스트 케이스 작성
- 인증 및 권한 검증 테스트

### 3. 시드 데이터 개선
- 샘플 오디오 파일 활용: 실제 음성 메시지 및 브로드캐스트 생성
- 환경별 URL 설정: 개발, 테스트, 프로덕션 환경에 따른 적응형 경로
- Broadcast 모델 속성 최적화: 불필요한 text 속성 제거
- 시드 데이터 로깅 개선: 상세한 진행 상황 표시

### 4. API 문서화
- Swagger UI 통합 및 문서 업데이트
- 새로운 엔드포인트 및 모델 추가
- 샘플 요청/응답 개선
- 레거시 API 엔드포인트 호환성 유지

## EAS 빌드 문제 해결 가이드

Expo Application Services(EAS)를 사용한 Android 앱 빌드 시 발생할 수 있는 문제와 해결 방법입니다.

### 주요 문제

#### 1. Keystore 생성 문제
EAS 빌드 서비스는 Android 앱을 빌드할 때 앱 서명에 필요한 Keystore를 요구합니다. 하지만 EAS 빌드는 기본적으로 **비대화형 모드(--non-interactive mode)**로 실행되며, 이 모드에서는 새로운 Keystore를 생성할 수 없습니다.

#### 2. cli.appVersionSource 설정 누락
"The field 'cli.appVersionSource' is not set, but it will be required in the future" 경고는 EAS CLI 설정에서 앱 버전 소스가 지정되지 않았음을 의미합니다.

### 해결 방법

#### 방법 1: 기존 Keystore 사용

이미 생성된 Keystore가 있는 경우:

1. **Keystore 파일 확인**
   - .jks 파일과 함께 해당 Keystore의 비밀번호, 키 별칭(alias), 키 비밀번호를 확인합니다.

2. **EAS에 업로드**
   ```bash
   eas credentials
   ```
   이 명령어를 실행하면 Android credentials 관리 메뉴가 나타나며, 기존 Keystore를 업로드할 수 있습니다.

3. **빌드 프로필 설정**
   - eas.json 파일의 production 프로필에 업로드된 Keystore가 사용되도록 확인합니다.

4. **빌드 재시도**
   ```bash
   eas build --platform android --profile production
   ```

#### 방법 2: 새로운 Keystore 생성 및 업로드

기존 Keystore가 없는 경우:

1. **로컬에서 EAS CLI 실행**
   ```bash
   npm install -g eas-cli
   eas credentials
   ```
   메뉴에서 Android를 선택하고, "Add a new keystore" 옵션을 선택하여 새로운 Keystore를 생성합니다.
   생성된 Keystore 정보(파일, 비밀번호, 별칭 등)는 안전하게 저장하세요.

2. **EAS에 업로드**
   - 생성된 Keystore가 자동으로 EAS에 업로드됩니다. 업로드가 완료되었는지 확인합니다.

3. **빌드 재시도**
   ```bash
   eas build --platform android --profile production
   ```

#### cli.appVersionSource 설정 추가

`eas.json` 파일에 다음 설정을 추가합니다:

```json
{
  "cli": {
    "appVersionSource": "remote"
  },
  "build": {
    "production": {
      "android": {
        "credentialsSource": "remote"
      }
    }
  }
}
```

- `"appVersionSource": "remote"`: EAS 서버에서 버전을 관리하도록 설정합니다.

이 설정을 추가한 후, 빌드를 다시 시도하면 경고가 사라집니다.

## Render 싱가포르 리전 Redis 및 Sidekiq 설정 가이드

오레곤 리전에서 싱가포르 리전으로 Redis와 Sidekiq 서비스를 마이그레이션하는 방법에 대한 가이드입니다.

## 설정 준비 사항

이 리포지토리에는 싱가포르 리전에 Redis 및 Sidekiq 서비스를 설정하기 위한 파일들이 포함되어 있습니다:

1. `render.yaml`: Render 서비스 Blueprint 정의
2. `config/initializers/sidekiq.rb`: 내부/외부 URL 자동 감지 기능이 있는 Sidekiq 설정
3. `redis_migration_guide.md`: 상세한 마이그레이션 단계별 안내
4. `bin/setup-render-singapore.sh`: 설정 확인 및 테스트를 위한 스크립트

## Render 대시보드에서 설정 단계

1. **싱가포르 리전에 새 Redis 인스턴스 생성**
   - Render 대시보드에서 "New +" > "Redis" 클릭
   - 이름: `singapore-redis`
   - 리전: `Singapore (Southeast Asia)`
   - 플랜: 필요에 맞는 플랜 선택
   - "Create" 클릭

2. **생성된 Redis 인스턴스의 내부 URL 확인**
   - Redis 서비스 대시보드에서 내부 URL 확인
   - 형식: `redis://singapore-redis:6379`

3. **API 서비스 업데이트**
   - API 서비스 대시보드로 이동
   - "Environment" 탭 클릭
   - `REDIS_URL` 환경 변수를 내부 URL로 업데이트
   - "Save Changes" 클릭

4. **새 Sidekiq 워커 생성**
   - "New +" > "Background Worker" 클릭
   - 리전: `Singapore (Southeast Asia)` 선택
   - 이름: `talkk-sidekiq`
   - 시작 명령어: `bundle exec sidekiq`
   - 환경 변수에 내부 Redis URL 추가
   - "Create" 클릭

5. **테스트 및 확인**
   - API 서비스 재배포
   - 로그 확인하여 Redis 연결 확인
   - Sidekiq 워커 로그에서 성공적인 시작 확인

## 로컬 개발 환경 설정

개발자 로컬 환경에서는 Docker Compose를 사용하여 동일한 설정을 테스트할 수 있습니다:

```bash
docker-compose up -d
```

이 명령은 Redis, PostgreSQL, API 서버, Sidekiq 워커를 로컬에서 실행합니다.

## 문제 해결

만약 연결 문제가 발생하면, 다음 명령으로 설정을 확인하고 테스트할 수 있습니다:

```bash
bin/setup-render-singapore.sh
```

자세한 마이그레이션 방법은 `redis_migration_guide.md` 문서를 참조하세요.

© 2024 Talkk. All rights reserved.