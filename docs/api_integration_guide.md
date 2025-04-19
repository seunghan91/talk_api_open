# Talkk API 연동 가이드

## 목차
1. [최신 업데이트 요약](#최신-업데이트-요약)
2. [사용자 모델 확장](#사용자-모델-확장)
3. [신고 및 차단 시스템](#신고-및-차단-시스템)
4. [관리자 대시보드](#관리자-대시보드)
5. [오디오 URL 시스템 개선](#오디오-url-시스템-개선)
6. [앱 통합 가이드](#앱-통합-가이드)

## 최신 업데이트 요약

### 2025-04-19 업데이트

1. **사용자 프로필 필드 확장**
   - 연령대(`age_group`) 및 지역(`region`) 정보 추가
   - 프로필 완성도 플래그(`profile_completed`) 추가

2. **신고 및 차단 시스템 강화**
   - 단계적 제재 시스템 구현 (신고 유형별 임계값 기반)
   - 계정 정지 기록 관리 및 자동 해제 기능
   - 관리자 신고 처리 대시보드 구현

3. **오디오 URL 시스템 개선**
   - 오디오 URL 유효 기간 7일로 연장 (환경 변수로 조정 가능)
   - 푸시 알림 시스템 안정화 (자동 재시도 및 로깅 강화)

## 사용자 모델 확장

### 신규 필드

```json
{
  "user": {
    "id": 123,
    "nickname": "사용자닉네임",
    "phone_number": "010****1234",
    "gender": "male", // "male", "female", "unknown" 중 하나
    "age_group": "30s", // "20s", "30s", "40s", "50s" 중 하나, null 가능
    "region": "서울/강남", // 국가/시도 형식, null 가능
    "profile_completed": false, // 프로필 완성 여부
    "blocked": false, // 계정 정지/차단 상태
    "warning_count": 0, // 경고 누적 횟수
    "created_at": "2025-01-01T00:00:00Z"
  }
}
```

### 관련 API 엔드포인트

#### 프로필 업데이트 (확장 필드 포함)

```http
POST /api/v1/users/update_profile
Content-Type: application/json
Authorization: Bearer {token}

{
  "user": {
    "gender": "male",
    "age_group": "30s",
    "region": "서울/강남"
  }
}
```

#### 응답

```json
{
  "user": { /* 업데이트된 사용자 정보 */ },
  "message": "프로필이 성공적으로 업데이트되었습니다."
}
```

## 신고 및 차단 시스템

### 신고 유형 및 처리 정책

| 신고 유형 | 임계값 | 제재 조치 |
|---------|--------|--------|
| 성별 위장 | 1회 | 즉시 1일 정지 (One-strike) |
| 불건전 콘텐츠 | 3회 | 3일 정지 |
| 일반 신고 | 5회 | 1일 정지 |

### API 엔드포인트

#### 사용자 신고하기

```http
POST /api/v1/reports
Content-Type: application/json
Authorization: Bearer {token}

{
  "report": {
    "reported_id": 123, // 신고할 사용자 ID
    "report_type": "user", // "user", "broadcast", "message" 중 하나
    "reason": "gender_impersonation", // "gender_impersonation", "inappropriate_content", "spam", "harassment", "other" 중 하나
    "related_id": 456 // 관련 브로드캐스트/메시지 ID (report_type이 "user"가 아닐 경우 필수)
  }
}
```

#### 응답

```json
{
  "report": { /* 생성된 신고 정보 */ },
  "message": "신고가 접수되었습니다. 검토 후 조치하겠습니다."
}
```

#### 사용자 차단하기

```http
POST /api/v1/users/{id}/block
Authorization: Bearer {token}
```

#### 응답

```json
{
  "message": "사용자가 차단되었습니다.",
  "blocked": true
}
```

#### 사용자 차단 해제하기

```http
POST /api/v1/users/{id}/unblock
Authorization: Bearer {token}
```

#### 응답

```json
{
  "message": "사용자 차단이 해제되었습니다.",
  "unblocked": true
}
```

#### 차단 목록 조회하기

```http
GET /api/v1/users/blocks
Authorization: Bearer {token}
```

#### 응답

```json
{
  "blocks": [
    {
      "id": 1,
      "blocked_id": 123,
      "created_at": "2025-01-01T00:00:00Z",
      "blocked_user": { /* 차단된 사용자 정보 */ }
    }
  ]
}
```

## 관리자 대시보드

관리자 대시보드는 웹 인터페이스로 구현되었으며, 다음 경로로 접근할 수 있습니다:

```
http://[서버 주소]/admin
```

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

## 오디오 URL 시스템 개선

### 주요 변경사항

- 오디오 URL 유효 기간 기본값 7일로 확장
- 환경 변수 `AUDIO_URL_EXPIRY_DAYS`로 관리자가 조절 가능
- 비동기 소통 목적에 맞게 콘텐츠 자체 만료 시간과 일관되게 관리

### 구현 세부사항

```ruby
# app/controllers/api/v1/broadcasts_controller.rb
# broadcast_response 메서드 내
audio_url_expiry = ENV.fetch('AUDIO_URL_EXPIRY_DAYS', '7').to_i.days
audio_url: broadcast.audio.attached? ? rails_blob_url(broadcast.audio, disposition: "attachment", expires_in: audio_url_expiry) : nil
```

## 앱 통합 가이드

### 필요한 파일 업데이트

1. **models.js**
   - 확장된 사용자 모델 정의
   - 신고, 차단, 계정 정지 관련 모델 정의 추가

2. **API 서비스 파일 추가**
   - `reportService.js`: 신고 및 차단 관련 API 호출
   - `profileService.js`: 확장된 프로필 필드 업데이트 관련 API 호출

### 앱 화면 업데이트 제안

1. **프로필 화면**
   - 연령대(`age_group`) 및 지역(`region`) 선택 UI 추가

2. **신고 기능**
   - 사용자/브로드캐스트/메시지 신고 기능 추가
   - 신고 사유 선택 UI 제공

3. **차단 기능**
   - 사용자 차단 및 차단 해제 기능
   - 차단 목록 화면 추가

### 알림 처리 업데이트

새로운 알림 유형이 추가되었으므로, 앱의 알림 처리 로직을 다음과 같이 업데이트해야 합니다:

```javascript
// 알림 처리 함수 예시
function handleNotification(notification) {
  switch (notification.type) {
    // 기존 알림 타입 처리
    case 'broadcast':
      // 브로드캐스트 알림 처리
      break;
    case 'message':
      // 메시지 알림 처리
      break;
    case 'system':
      // 시스템 알림 처리
      break;

    // 새로운 알림 타입 처리
    case 'account_warning':
      // 계정 경고 알림 처리
      showWarningAlert(notification.title, notification.body);
      break;
    case 'account_suspension':
      // 계정 정지 알림 처리
      showSuspensionAlert(notification.title, notification.body, notification.data.suspension_duration);
      break;
    case 'suspension_ended':
      // 정지 해제 알림 처리
      showSuspensionEndedAlert(notification.title, notification.body);
      break;
  }
}
```

### 로그인 후 차단 상태 확인

사용자의 로그인 시, 계정 정지 상태(`blocked`)를 확인하여 정지된 사용자에게 적절한 안내 메시지를 표시해야 합니다:

```javascript
// 로그인 후 사용자 정보 확인
async function checkUserStatus() {
  try {
    const userProfile = await profileService.getMyProfile();
    
    if (userProfile.user.blocked) {
      // 정지된 계정 처리 (예: 정지 안내 화면으로 이동)
      showBlockedAccountScreen(userProfile.user);
      return false;
    }
    
    return true;
  } catch (error) {
    console.error('사용자 상태 확인 중 오류 발생:', error);
    return false;
  }
}
```

## API 문서화

최신 API 문서는 다음 경로에서 확인할 수 있습니다:

```
http://[서버 주소]/api-docs
```

이 문서는 OpenAPI 3.0 표준을 따르며, 모든 엔드포인트, 요청/응답 형식, 인증 방법 등을 포함합니다.
