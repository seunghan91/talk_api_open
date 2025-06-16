#!/bin/bash

# Render 배포 스크립트
# API 키가 환경변수로 설정되어 있어야 함: export RENDER_API_KEY=your_api_key

set -e  # 오류 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 서비스 ID
API_SERVICE_ID="srv-cvbri10fnakc73dntmsg"
SIDEKIQ_SERVICE_ID="srv-cvlm6cbipnbc73as48ag"

echo -e "${BLUE}🚀 Render 배포 시작${NC}"

# API 키 확인
if [ -z "$RENDER_API_KEY" ]; then
    echo -e "${RED}❌ RENDER_API_KEY 환경변수가 설정되지 않았습니다.${NC}"
    echo "다음 명령어로 설정하세요:"
    echo "export RENDER_API_KEY=rnd_nl7EilaRTB974H5EXZYeiIhE2jTm"
    exit 1
fi

echo -e "${GREEN}✅ API 키 확인 완료${NC}"

# 1. API 서버 배포
echo -e "${YELLOW}📦 API 서버 배포 중...${NC}"
render deploys create $API_SERVICE_ID --output json --confirm --wait

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ API 서버 배포 완료${NC}"
else
    echo -e "${RED}❌ API 서버 배포 실패${NC}"
    exit 1
fi

# 2. Sidekiq 워커 배포
echo -e "${YELLOW}⚙️ Sidekiq 워커 배포 중...${NC}"
render deploys create $SIDEKIQ_SERVICE_ID --output json --confirm --wait

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Sidekiq 워커 배포 완료${NC}"
else
    echo -e "${RED}❌ Sidekiq 워커 배포 실패${NC}"
    exit 1
fi

# 3. 서비스 상태 확인
echo -e "${YELLOW}🔍 서비스 상태 확인 중...${NC}"
render services --output json --confirm | jq '.[] | select(.service) | {name: .service.name, status: .service.suspended, url: .service.serviceDetails.url}'

echo -e "${GREEN}🎉 모든 배포가 완료되었습니다!${NC}"
echo -e "${BLUE}🌐 API URL: https://talkk-api.onrender.com${NC}" 