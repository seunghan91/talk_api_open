#!/bin/bash

# 싱가포르 리전에 Redis 및 Sidekiq 설정 스크립트
echo "=== Render 싱가포르 리전 Redis 및 Sidekiq 설정 스크립트 ==="

# 1. 로컬 Redis 확인
echo "로컬 Redis 연결 테스트 중..."
redis-cli ping || {
  echo "로컬 Redis 연결 실패. 계속 진행합니다."
}

# 2. 환경 변수 설정
echo "환경 변수 확인 중..."
if [ -z "$REDIS_URL" ]; then
  echo "REDIS_URL 환경 변수가 설정되지 않았습니다. render.yaml 파일에 정의된 내부 URL이 사용됩니다."
else
  echo "REDIS_URL 환경 변수 확인: ${REDIS_URL//:*@/:***@}"
fi

# 3. Sidekiq 구성 확인
echo "Sidekiq 구성 확인 중..."
if [ -f "config/initializers/sidekiq.rb" ]; then
  echo "Sidekiq 구성 파일 찾음: config/initializers/sidekiq.rb"
else
  echo "경고: config/initializers/sidekiq.rb 파일이 없습니다!"
fi

# 4. 내부 URL 테스트 (Render 내부에서만 작동)
echo "Redis 내부 URL 테스트 중... (Render 환경에서만 작동)"
if [ -n "$REDIS_URL" ] && [[ "$REDIS_URL" != *"rediss://"* ]]; then
  REDIS_HOST=$(echo $REDIS_URL | sed -E 's/redis:\/\/(:[^@]*@)?([^:]+).*/\2/')
  echo "Redis 호스트 추출: $REDIS_HOST"
  redis-cli -h $REDIS_HOST ping || echo "내부 URL 연결 실패. Render 외부에서 실행 중인 것 같습니다."
else
  echo "외부 SSL URL이 감지되었습니다. 내부 URL 테스트를 건너뜁니다."
fi

# 5. 배포 정보 출력
echo ""
echo "=== 배포 정보 ==="
echo "render.yaml 파일에 정의된 서비스가 Render 대시보드에 배포됩니다."
echo "1. singapore-redis: 싱가포르 리전의 Redis 인스턴스"
echo "2. talkk-api: 싱가포르 리전의 API 서버"
echo "3. talkk-sidekiq: 싱가포르 리전의 Sidekiq 워커"
echo ""
echo "배포 후 확인할 사항:"
echo "- Render 대시보드에서 각 서비스의 로그 확인"
echo "- API 서버와 Sidekiq 모두 Redis에 연결되는지 확인"
echo "- Sidekiq 워커가 작업을 처리하는지 확인"
echo ""
echo "설정 스크립트 완료." 