# Render 싱가포르 리전 설정 가이드 

현재 Render CLI 2.1.1에서는 블루프린트 배포 및 서비스 생성 기능이 제한적이므로, 웹 대시보드를 통한 설정 방법을 안내합니다.

## 1. Render 웹 대시보드에서 Blueprint 배포

1. [Render 대시보드](https://dashboard.render.com/)에 로그인합니다.
2. 왼쪽 사이드바에서 "Blueprints" 메뉴를 클릭합니다.
3. "New Blueprint" 버튼을 클릭합니다.
4. GitHub 저장소를 선택하고, `talk_api_open` 저장소를 선택합니다.
5. `render.yaml` 파일이 자동으로 감지됩니다.
6. 다음 서비스들이 모두 싱가포르 리전에 설정되어 있는지 확인합니다:
   - `singapore-redis` (Redis)
   - `talkk-api` (Web Service)
   - `talkk-sidekiq` (Background Worker)
7. "Apply Blueprint" 버튼을 클릭하여 배포를 시작합니다.

## 2. 수동으로 서비스 설정 (Blueprint를 사용하지 않는 경우)

### 2.1 싱가포르 리전에 Redis 인스턴스 생성

1. Render 대시보드에서 "New +" 버튼을 클릭합니다.
2. "Redis" 옵션을 선택합니다.
3. 다음 설정을 입력합니다:
   - **Name**: `singapore-redis`
   - **Region**: `Singapore (Southeast Asia)`
   - **Plan**: `Starter` 또는 필요에 맞는 플랜
4. "Create Redis" 버튼을 클릭합니다.
5. 생성되면 **내부 URL**을 기록해둡니다: `redis://singapore-redis:6379`

### 2.2 API 서비스 설정

1. 현재 `talkk-api` 서비스 설정 페이지로 이동합니다.
2. "Settings" 탭을 클릭합니다.
3. "Region" 설정을 "Singapore (Southeast Asia)"로 변경합니다.
4. "Environment" 섹션으로 이동하여 `REDIS_URL` 환경 변수를 찾습니다.
5. 해당 변수를 이전에 기록한 내부 URL로 업데이트합니다.
6. "Save Changes" 버튼을 클릭합니다.

### 2.3 Sidekiq 워커 생성

1. "New +" 버튼을 클릭합니다.
2. "Background Worker" 옵션을 선택합니다.
3. GitHub 저장소에서 `talk_api_open` 저장소를 선택합니다.
4. 다음 설정을 입력합니다:
   - **Name**: `talkk-sidekiq`
   - **Region**: `Singapore (Southeast Asia)`
   - **Branch**: `main`
   - **Build Command**: `bundle install`
   - **Start Command**: `bundle exec sidekiq`
5. 환경 변수에 다음을 추가합니다:
   - `REDIS_URL`: 내부 Redis URL
   - `RAILS_ENV`: `production`
   - API 서비스와 동일한 다른 환경 변수들
6. "Create Background Worker" 버튼을 클릭합니다.

## 3. 배포 및 확인

1. API 서비스를 선택합니다.
2. "Manual Deploy" > "Deploy latest commit" 버튼을 클릭합니다.
3. 로그를 모니터링하여 배포 상태를 확인합니다.
4. Redis 연결 로그가 성공적으로 표시되는지 확인합니다.
5. Sidekiq 워커의 로그도 확인하여 정상 작동하는지 확인합니다.

## 4. 기존 오레곤 리전 서비스 정리

모든 서비스가 싱가포르에서 정상 작동하는 것을 확인한 후:

1. 오레곤 리전의 Redis 인스턴스로 이동합니다.
2. "Settings" 탭에서 "Delete Service" 버튼을 클릭합니다.
3. 확인 대화 상자에서 서비스 이름을 입력하고 삭제를 완료합니다.
4. 필요한 경우 오레곤 리전의 다른 서비스도 동일한 방법으로 정리합니다.

## 5. 문제 해결

### 5.1 Redis 연결 오류

다음과 같은 오류가 발생하는 경우:
```
getaddrinfo: Name or service not known (redis://singapore-redis:6379)
```

**해결 방법**:
1. 내부 URL이 정확한지 확인합니다.
2. 두 서비스가 같은 리전(싱가포르)에 있는지 확인합니다.
3. Redis 서비스가 정상적으로 실행 중인지 확인합니다.

### 5.2 Sidekiq 시작 실패

**해결 방법**:
1. Sidekiq 워커의 로그를 확인합니다: `render logs talkk-sidekiq`
2. 환경 변수 설정을 확인합니다.
3. 필요한 경우 Sidekiq 워커를 재시작합니다.

## 6. 로컬 테스트

로컬 개발 환경에서도 새 설정을 테스트할 수 있습니다:

```bash
# Docker Compose를 사용하여 모든 서비스 시작
docker-compose up -d

# 개별 서비스 로그 확인
docker-compose logs -f api
docker-compose logs -f sidekiq
docker-compose logs -f redis

# Redis 연결 테스트
docker-compose exec redis redis-cli ping
```

이 설정으로 API 서버와 Redis 인스턴스가 동일한 리전(싱가포르)에서 실행되어 지연 시간이 감소하고 안정성이 향상됩니다. 