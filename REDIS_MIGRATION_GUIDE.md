# Redis 마이그레이션 가이드: 오레곤에서 싱가포르로

이 가이드는 Render에서 Redis 인스턴스를 오레곤에서 싱가포르로 이동하는 방법을 설명합니다.

## 1. 싱가포르에 새 Redis 인스턴스 생성

1. Render 대시보드에 로그인하세요
2. 왼쪽 메뉴에서 "New +"를 클릭하고 "Redis"를 선택하세요
3. 다음 설정으로 새 Redis 인스턴스를 구성하세요:
   - **이름**: `singapore-keyvalue` (원하는 이름 사용)
   - **지역**: `Singapore (Southeast Asia)`
   - **플랜**: 필요에 맞는 플랜 선택
   - **Redis 버전**: 기존 인스턴스와 동일한 버전 선택
4. "Create Redis" 버튼을 클릭하여 생성합니다

## 2. 내부 네트워크 URL 확인 및 환경 변수 설정

1. 새 Redis 인스턴스가 생성되면 세부 정보 페이지로 이동합니다
2. 두 가지 URL을 확인할 수 있습니다:
   - **External URL**: `rediss://user:password@singapore-keyvalue.render.com:6379`
   - **Internal URL**: `redis://singapore-keyvalue:6379`

3. API 서버의 환경 변수 설정:
   - API 서버 대시보드로 이동
   - "Environment" 탭 클릭
   - 기존 `REDIS_URL` 환경 변수를 찾아 수정 또는 새로 추가
   - 값을 내부 URL로 설정: `redis://singapore-keyvalue:6379`
   - 비밀번호가 필요하면 내부 URL에 추가: `redis://:password@singapore-keyvalue:6379`
   - "Save Changes" 클릭

## 3. API 서버 재배포 및 테스트

1. API 서버를 재배포하세요:
   - API 서버 대시보드로 이동
   - "Manual Deploy" > "Deploy latest commit" 클릭

2. 로그를 확인하여 Sidekiq 연결 성공을 확인하세요:
   ```bash
   render logs talkk-api
   ```

3. Redis 연결 테스트:
   - 내부 URL 테스트 (Render 콘솔에서):
     ```bash
     redis-cli -h singapore-keyvalue -p 6379 ping
     ```
   
   - 외부 URL 테스트 (로컬에서):
     ```bash
     redis-cli --tls -h singapore-keyvalue.render.com -p 6379 -a password ping
     ```

## 4. 테스트 성공 후 기존 Redis 인스턴스 삭제

1. 모든 것이 정상 작동하는지 확인한 후
2. Render 대시보드에서 오레곤 Redis 인스턴스로 이동
3. "Settings" 탭 클릭
4. 페이지 하단에서 "Delete Service" 클릭

## 주의사항

1. **가동 중지 시간 최소화**: 마이그레이션은 짧은 가동 중지 시간을 초래할 수 있으므로 트래픽이 적은 시간에 진행하세요.
2. **비용 고려**: 잠시 두 Redis 인스턴스를 동시에 실행하게 되므로 추가 비용이 발생합니다.
3. **내부 네트워크 이점**: 내부 URL을 사용하면 지연 시간이 감소하고 보안이 향상됩니다.

## 문제 해결

- **연결 오류**: 내부 URL로 연결 시 문제가 발생하면 외부 URL을 사용해보세요. 그러나 이 경우 `ssl: true` 설정이 필요합니다.
- **인증 실패**: 비밀번호가 올바르게 포함되었는지 확인하세요: `redis://:password@singapore-keyvalue:6379`
- **지연 시간 문제**: 싱가포르와 API 서버 간의 지연 시간을 확인하세요. 내부 네트워크를 사용하면 지연 시간이 크게 줄어야 합니다.
