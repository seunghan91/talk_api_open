# Render CLI 스크립트 가이드

이 디렉터리에는 Render 배포 및 로그 모니터링을 위한 스크립트들이 있습니다.

## 🚀 배포 스크립트 (`deploy.sh`)

### 사용법
```bash
# API 키 설정 (처음 한 번만)
export RENDER_API_KEY=rnd_nl7EilaRTB974H5EXZYeiIhE2jTm

# 배포 실행
./scripts/deploy.sh
```

### 기능
- API 서버 배포 (`talkk-api`)
- Sidekiq 워커 배포 (`talkk-sidekiq`)
- 배포 완료 후 서비스 상태 확인
- 에러 발생 시 자동 중단

---

## 📊 로그 모니터링 스크립트 (`logs.sh`)

### 사용법
```bash
# API 서버 실시간 로그 (기본값)
./scripts/logs.sh
./scripts/logs.sh api

# Sidekiq 워커 실시간 로그
./scripts/logs.sh sidekiq

# 최근 로그 확인 (API + Sidekiq 각각 20개)
./scripts/logs.sh recent

# 에러 로그만 확인
./scripts/logs.sh errors

# 도움말
./scripts/logs.sh help
```

### 기능
- 실시간 로그 스트리밍
- 최근 로그 확인
- 에러 로그 필터링
- 색상 출력으로 가독성 향상

---

## 🔧 GitHub Actions

### 설정 방법
1. GitHub 저장소의 Settings > Secrets and variables > Actions로 이동
2. 다음 시크릿 추가:
   - `RENDER_API_KEY`: `rnd_nl7EilaRTB974H5EXZYeiIhE2jTm`

### 자동 배포
- `main` 브랜치에 push할 때 자동 배포
- 수동 배포: Actions 탭에서 "Render Deploy via CLI" 워크플로우 실행

---

## 📝 주요 Render CLI 명령어

### 서비스 관리
```bash
# 서비스 목록 확인
render services --output json --confirm

# 배포 생성
render deploys create <SERVICE_ID> --output json --confirm --wait

# 배포 이력 확인
render deploys list <SERVICE_ID> --output json --confirm
```

### 로그 모니터링
```bash
# 실시간 로그 스트리밍
render logs --tail -r <SERVICE_ID> --output text --confirm

# 최근 N개 로그
render logs --limit 20 -r <SERVICE_ID> --output text --confirm

# 에러 로그만
render logs --level error -r <SERVICE_ID> --output text --confirm

# 특정 시간대 로그
render logs --start "2025-06-16T06:00:00Z" --end "2025-06-16T07:00:00Z" -r <SERVICE_ID>
```

### 기타 유용한 명령어
```bash
# SSH 접속
render ssh <SERVICE_ID>

# PostgreSQL 접속
render psql <DATABASE_ID>

# 서비스 상태 확인
render services --output json --confirm | jq '.[] | select(.service) | {name: .service.name, status: .service.suspended}'
```

---

## 🏷️ 서비스 ID 참조

- **API 서버**: `srv-cvbri10fnakc73dntmsg` (talkk-api)
- **Sidekiq 워커**: `srv-cvlm6cbipnbc73as48ag` (talkk-sidekiq)
- **PostgreSQL**: `dpg-cvbrhngfnakc73dntkhg-a` (talkk-db)
- **Redis**: `red-cvlm54adbo4c7399oheg` (talk-redis)

---

## 🔗 유용한 링크

- [Render Dashboard](https://dashboard.render.com)
- [API 서버 URL](https://talkk-api.onrender.com)
- [Render CLI 문서](https://render.com/docs/cli) 