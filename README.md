# Talkk API

음성 기반 소셜 미디어 플랫폼 Talkk의 백엔드 API

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
| 김철수 | 01011111111 | 123456 |
| 이영희 | 01022222222 | 123456 |
| 박지민 | 01033333333 | 123456 |
| 관리자 | 01099999999 | admin123 |

이 계정들을 이용해 음성 메시지 전송 및 브로드캐스트 기능을 테스트할 수 있습니다.

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

## 배포 가이드

Talkk API는 다양한 방법으로 배포할 수 있습니다. 아래는 몇 가지 추천 배포 방법입니다.

### 1. Render.com을 이용한 배포

[Render](https://render.com/)는 Rails 애플리케이션을 쉽게 배포할 수 있는 클라우드 플랫폼입니다.

#### 장점
- 간편한 설정과 배포 과정
- PostgreSQL 및 Redis 서비스 통합 제공
- 무료 티어 제공 (제한적이지만 테스트에 충분)
- Git 저장소와 연동하여 자동 배포 가능

#### 배포 방법
1. Render.com에 가입하고 새 Web Service 생성
2. GitHub/GitLab 저장소 연결
3. 환경 설정:
   - 빌드 명령어: `bundle install`
   - 시작 명령어: `bundle exec rails server -b 0.0.0.0`
4. 데이터베이스 설정: Render PostgreSQL 서비스 생성 및 연결
5. 환경 변수 설정 (DATABASE_URL, RAILS_MASTER_KEY 등)

### 2. SSL 인증서 설정

보안 연결을 위해 SSL 인증서를 설정하는 방법입니다.

#### Render.com에서 SSL 설정
Render.com은 모든 서비스에 자동으로 SSL을 제공합니다:

1. 웹 서비스 생성 시 자동으로 Let's Encrypt SSL 인증서가 발급됨
2. 커스텀 도메인을의 경우:
   - Render 대시보드에서 웹 서비스 선택
   - 'Settings' > 'Custom Domain' 섹션으로 이동
   - 도메인 추가 및 DNS 설정 지침 따르기
   - 도메인 확인 후 자동으로 SSL 인증서 발급

#### 수동 SSL 설정 (자체 서버)
자체 서버에 배포할 경우 Certbot을 사용한 Let's Encrypt SSL 설정:

```bash
# Certbot 설치
sudo apt-get update
sudo apt-get install certbot

# Nginx와 함께 사용할 경우
sudo apt-get install python3-certbot-nginx

# SSL 인증서 발급
sudo certbot --nginx -d yourdomain.com

# 자동 갱신 확인
sudo certbot renew --dry-run
```

#### Rails 애플리케이션 SSL 설정
production.rb 파일에 다음 설정 추가:

```ruby
# config/environments/production.rb
config.force_ssl = true
```

### 3. 영구 스토리지 설정

Render.com에서 영구 스토리지 설정 방법:

1. Render 대시보드에서 'Disks' 메뉴 선택
2. 새 디스크 생성 (이름, 크기 지정)
3. 웹 서비스에 디스크 연결 (마운트 경로 지정: 예 - `/mnt/activestorage`)
4. storage.yml 파일 수정:

```yaml
# config/storage.yml
production:
  service: Disk
  root: "/mnt/activestorage"
```

5. 환경 파일 수정:

```ruby
# config/environments/production.rb
config.active_storage.service = :production
```

## 베타 테스트 환경 구성 가이드

베타 테스트를 위한 환경을 구성하려면 다음 단계를 따르세요:

1. **배포 환경 선택**: 위에서 설명한 배포 방법 중 하나를 선택하여 API 서버 배포
2. **도메인 설정**: 필요한 경우 커스텀 도메인 연결
3. **SSL 인증서**: HTTPS 활성화 (대부분의 클라우드 서비스에서 자동 제공)
4. **모바일 앱 설정**: API 엔드포인트를 배포된 서버 URL로 업데이트
5. **테스트 계정 생성**: `rails db:seed` 명령으로 테스터들을 위한 계정 생성
6. **모니터링 설정**: 로그 및 성능 모니터링 도구 연결 (예: New Relic, Datadog)
7. **피드백 시스템**: 테스터들이 피드백을 제출할 수 있는 시스템 구축 (예: Google Forms, Typeform)

## 문제 해결

배포 중 발생할 수 있는 일반적인 문제와 해결 방법:

1. **데이터베이스 연결 오류**: 환경 변수 `DATABASE_URL`이 올바르게 설정되었는지 확인
2. **Active Storage 설정**: 클라우드 스토리지 서비스(AWS S3, Google Cloud Storage 등) 연결 확인
3. **Redis 연결 오류**: Redis URL 환경 변수 확인
4. **Sidekiq 작업 실패**: Redis 연결 및 Sidekiq 프로세스 실행 여부 확인
5. **CORS 오류**: `config/initializers/cors.rb` 파일에서 허용된 도메인 확인
6. **음성 파일 저장 오류**: 스토리지 경로 권한 확인, 영구 디스크 마운트 상태 확인
7. **SSL 인증서 문제**: 인증서 만료 여부 확인, DNS 설정 검증

## API 엔드포인트

주요 API 엔드포인트는 다음과 같습니다:

### 인증 관련
- `POST /api/auth/request_code`: SMS 인증 코드 요청
- `POST /api/auth/verify_code`: SMS 인증 코드 확인
- `POST /api/auth/register`: 회원가입
- `POST /api/auth/login`: 로그인
- `POST /api/auth/logout`: 로그아웃

### 사용자 관련
- `GET /api/users/profile`: 사용자 프로필 조회
- `POST /api/users/update_profile`: 프로필 업데이트
- `GET /api/users/notification_settings`: 알림 설정 조회
- `POST /api/users/notification_settings`: 알림 설정 업데이트

### 브로드캐스트 관련
- `GET /api/broadcasts`: 브로드캐스트 목록 조회
- `POST /api/broadcasts`: 브로드캐스트 생성
- `GET /api/broadcasts/:id`: 특정 브로드캐스트 조회
- `POST /api/broadcasts/:id/reply`: 브로드캐스트에 답장

### 대화 관련
- `GET /api/conversations`: 대화 목록 조회
- `GET /api/conversations/:id`: 특정 대화 조회
- `POST /api/conversations/:id/messages`: 대화에 메시지 전송
- `DELETE /api/conversations/:id`: 대화방 삭제

### 차단 및 신고 관련
- `POST /api/reports`: 사용자 신고
- `POST /api/blocks`: 사용자 차단
- `DELETE /api/blocks/:id`: 차단 해제

---

© 2024 Talkk. All rights reserved.