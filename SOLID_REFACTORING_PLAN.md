# SOLID 원칙 기반 리팩토링 계획

## 📋 목차
1. [현재 상태 분석](#현재-상태-분석)
2. [SOLID 원칙 위반 사항](#solid-원칙-위반-사항)
3. [개선 아키텍처](#개선-아키텍처)
4. [구현 계획](#구현-계획)
5. [예상 결과](#예상-결과)

## 🔍 현재 상태 분석

### Backend (Rails API)
- **모놀리틱 컨트롤러**: AuthController가 500+ 라인으로 너무 많은 책임
- **비즈니스 로직 분산**: Controller, Model, Worker에 흩어져 있음
- **의존성 하드코딩**: 직접적인 클래스 참조, DI 부족
- **인터페이스 부재**: 구체적 구현에 의존

### Frontend (React Native)
- **컴포넌트 책임 과다**: VoiceRecorder가 녹음/재생/업로드 모두 처리
- **비즈니스 로직 혼재**: UI 컴포넌트에 API 호출 로직 포함
- **상태 관리 일관성 부족**: Context, Redux, 로컬 state 혼용
- **재사용성 부족**: 유사 기능들이 중복 구현

## 🚨 SOLID 원칙 위반 사항

### 1. Single Responsibility Principle (SRP) 위반

#### Backend
```ruby
# ❌ 현재: AuthController가 너무 많은 책임
class AuthController
  def login           # 로그인
  def register        # 회원가입
  def request_code    # 인증코드 요청
  def verify_code     # 인증코드 검증
  def reset_password  # 비밀번호 재설정
  # ... 500+ lines
end

# ❌ 현재: Message 모델이 너무 많은 책임
class Message
  # 메시지 생성, 검증, 파일 처리, 알림 생성 등
end
```

#### Frontend
```javascript
// ❌ 현재: 하나의 컴포넌트가 너무 많은 일을 함
const VoiceRecorder = () => {
  // 권한 처리, 녹음, 재생, 업로드, UI 렌더링
};
```

### 2. Open/Closed Principle (OCP) 위반

#### Backend
```ruby
# ❌ 현재: 새로운 인증 방식 추가 시 기존 코드 수정 필요
def verify_code
  if Rails.env.development? && code == "111111"
    # 하드코딩된 개발 환경 처리
  end
end
```

#### Frontend
```javascript
// ❌ 현재: 새로운 녹음 포맷 지원 시 기존 코드 수정 필요
if (recordingUri.endsWith('.m4a')) {
  // m4a 처리
} else if (recordingUri.endsWith('.mp3')) {
  // mp3 처리
}
```

### 3. Liskov Substitution Principle (LSP) 위반

#### Backend
```ruby
# ❌ 현재: 서브클래스가 부모 클래스와 다른 동작
class TestUser < User
  def can_broadcast?
    true  # 항상 true 반환 (부모 클래스의 계약 위반)
  end
end
```

### 4. Interface Segregation Principle (ISP) 위반

#### Backend
```ruby
# ❌ 현재: 너무 큰 인터페이스
class User
  # 인증, 프로필, 방송, 메시지, 지갑 등 모든 기능
end
```

#### Frontend
```javascript
// ❌ 현재: 불필요한 props 전달
<VoiceRecorder
  onRecordingComplete={...}
  maxDuration={...}
  style={...}
  recordingMessage={...}
  // 사용하지 않는 props들도 전달
/>
```

### 5. Dependency Inversion Principle (DIP) 위반

#### Backend
```ruby
# ❌ 현재: 구체적 구현에 의존
class BroadcastWorker
  def perform
    User.find(id)  # ActiveRecord에 직접 의존
    Redis.current.get  # Redis에 직접 의존
  end
end
```

#### Frontend
```javascript
// ❌ 현재: 구체적 구현에 의존
const login = async () => {
  const response = await axiosInstance.post('/auth/login');  // axios에 직접 의존
};
```

## 🏗️ 개선 아키텍처

### Backend 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Controllers │  │   GraphQL   │  │  WebSocket  │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────┐
│                    Application Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Commands   │  │   Queries   │  │   Events    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────┐
│                     Domain Layer                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Entities   │  │Value Objects│  │  Services   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────┐
│                 Infrastructure Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │Repositories │  │   Storage   │  │External APIs│     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### Frontend 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │    Pages    │  │ Components  │  │   Layouts   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────┐
│                    Business Logic Layer                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Hooks     │  │  Services   │  │   Stores    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────┐
│                      Data Layer                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ API Client  │  │   Storage   │  │    Cache    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

## 📝 구현 계획

### Phase 1: Backend 리팩토링 (Week 1-2)

#### 1.1 Controller 분리 (SRP)
```ruby
# app/controllers/api/v1/auth/phone_verifications_controller.rb
module Api::V1::Auth
  class PhoneVerificationsController < BaseController
    def create  # POST /auth/phone-verifications
    def verify  # POST /auth/phone-verifications/verify
  end
end

# app/controllers/api/v1/auth/registrations_controller.rb
module Api::V1::Auth
  class RegistrationsController < BaseController
    def create  # POST /auth/registrations
  end
end

# app/controllers/api/v1/auth/sessions_controller.rb
module Api::V1::Auth
  class SessionsController < BaseController
    def create   # POST /auth/sessions (login)
    def destroy  # DELETE /auth/sessions (logout)
  end
end
```

#### 1.2 Command/Query 패턴 도입 (SRP, DIP)
```ruby
# app/commands/auth/register_user_command.rb
module Auth
  class RegisterUserCommand
    def initialize(phone_number:, password:, nickname:)
      @phone_number = phone_number
      @password = password
      @nickname = nickname
    end

    def execute
      # 비즈니스 로직만 처리
    end
  end
end

# app/queries/broadcasts/find_recipients_query.rb
module Broadcasts
  class FindRecipientsQuery
    def initialize(sender:, count:)
      @sender = sender
      @count = count
    end

    def execute
      # 쿼리 로직만 처리
    end
  end
end
```

#### 1.3 Repository 패턴 도입 (DIP)
```ruby
# app/repositories/user_repository.rb
class UserRepository
  include Repository::Base
  
  def find_by_phone(phone_number)
    User.find_by(phone_number: phone_number)
  end
  
  def create_with_wallet(attributes)
    transaction do
      user = User.create!(attributes)
      Wallet.create!(user: user)
      user
    end
  end
end
```

#### 1.4 Service 객체 리팩토링 (SRP, OCP)
```ruby
# app/services/auth/verification_service.rb
module Auth
  class VerificationService
    def initialize(strategy: SmsVerificationStrategy.new)
      @strategy = strategy
    end
    
    def send_code(phone_number)
      @strategy.send_code(phone_number)
    end
    
    def verify_code(phone_number, code)
      @strategy.verify_code(phone_number, code)
    end
  end
end
```

### Phase 2: Frontend 리팩토링 (Week 2-3)

#### 2.1 컴포넌트 분리 (SRP)
```javascript
// components/voice/VoiceRecorderButton.tsx
export const VoiceRecorderButton: React.FC<Props> = ({ onPress, isRecording }) => {
  // UI만 담당
};

// hooks/useVoiceRecording.ts
export const useVoiceRecording = () => {
  // 녹음 로직만 담당
  return { startRecording, stopRecording, recordingState };
};

// services/audio/AudioRecordingService.ts
export class AudioRecordingService {
  // 오디오 처리만 담당
  async startRecording(): Promise<void> {}
  async stopRecording(): Promise<string> {}
}
```

#### 2.2 API 레이어 추상화 (DIP)
```typescript
// api/interfaces/IAuthApi.ts
export interface IAuthApi {
  login(phone: string, password: string): Promise<AuthResponse>;
  register(data: RegisterData): Promise<AuthResponse>;
  verifyPhone(phone: string, code: string): Promise<VerifyResponse>;
}

// api/implementations/AuthApiImpl.ts
export class AuthApiImpl implements IAuthApi {
  constructor(private httpClient: IHttpClient) {}
  
  async login(phone: string, password: string): Promise<AuthResponse> {
    return this.httpClient.post('/auth/login', { phone, password });
  }
}
```

#### 2.3 상태 관리 통합 (SRP)
```typescript
// store/slices/authSlice.ts
export const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    // 인증 관련 상태만 관리
  }
});

// store/slices/broadcastSlice.ts
export const broadcastSlice = createSlice({
  name: 'broadcast',
  initialState,
  reducers: {
    // 방송 관련 상태만 관리
  }
});
```

### Phase 3: 통합 및 최적화 (Week 3-4)

#### 3.1 이벤트 기반 아키텍처
```ruby
# app/events/broadcast_created_event.rb
class BroadcastCreatedEvent < ApplicationEvent
  attr_reader :broadcast_id, :sender_id
  
  def initialize(broadcast_id:, sender_id:)
    @broadcast_id = broadcast_id
    @sender_id = sender_id
  end
end

# app/subscribers/notification_subscriber.rb
class NotificationSubscriber
  def on_broadcast_created(event)
    # 알림 처리만 담당
  end
end
```

#### 3.2 의존성 주입 컨테이너
```ruby
# config/initializers/dependencies.rb
Dependencies.register do
  singleton :user_repository, UserRepository
  singleton :notification_service, NotificationService
  
  factory :register_user_command do |c|
    Auth::RegisterUserCommand.new(
      user_repository: c.user_repository,
      notification_service: c.notification_service
    )
  end
end
```

## 🎯 예상 결과

### 1. 유지보수성 향상
- 각 클래스가 하나의 책임만 가짐
- 새 기능 추가 시 기존 코드 수정 불필요
- 테스트 작성이 쉬워짐

### 2. 확장성 개선
- 새로운 인증 방식 추가 가능
- 새로운 파일 포맷 지원 가능
- 새로운 알림 채널 추가 가능

### 3. 코드 품질 향상
- 명확한 의존성 관계
- 일관된 아키텍처 패턴
- 재사용 가능한 컴포넌트

### 4. 개발 속도 향상
- 병렬 개발 가능
- 명확한 인터페이스로 협업 개선
- 버그 감소

## 📊 성공 지표

1. **코드 메트릭스**
   - 클래스당 평균 라인 수: 500 → 100 이하
   - 메서드당 평균 라인 수: 50 → 10 이하
   - 순환 복잡도: 10 → 5 이하

2. **아키텍처 메트릭스**
   - 의존성 방향: 단방향 유지
   - 결합도: 느슨한 결합
   - 응집도: 높은 응집도

3. **개발 효율성**
   - 새 기능 추가 시간: 50% 감소
   - 버그 수정 시간: 70% 감소
   - 코드 리뷰 시간: 30% 감소 