#!/bin/bash

# Render 로그 모니터링 스크립트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 서비스 ID
API_SERVICE_ID="srv-cvbri10fnakc73dntmsg"

# 사용법 출력
usage() {
    echo -e "${BLUE}Render 로그 모니터링 스크립트${NC}"
    echo ""
    echo "사용법:"
    echo "  $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  api        API 서버 로그 (실시간)"
    echo "  recent     최근 로그 확인"
    echo "  errors     에러 로그만 확인"
    echo "  tail       실시간 스트리밍 (기본값)"
    echo ""
    echo "예시:"
    echo "  $0 api          # API 서버 실시간 로그"
    echo "  $0 recent       # 최근 20개 로그 확인"
    echo "  $0 errors       # 에러 로그만 확인"
}

# API 키 확인
check_api_key() {
    if [ -z "$RENDER_API_KEY" ]; then
        echo -e "${RED}❌ RENDER_API_KEY 환경변수가 설정되지 않았습니다.${NC}"
        echo "다음 명령어로 설정하세요:"
        echo "export RENDER_API_KEY=rnd_nl7EilaRTB974H5EXZYeiIhE2jTm"
        exit 1
    fi
}

# API 서버 실시간 로그
api_logs() {
    echo -e "${GREEN}🌐 API 서버 실시간 로그 스트리밍 시작...${NC}"
    echo -e "${YELLOW}종료하려면 Ctrl+C를 누르세요${NC}"
    render logs --tail -r $API_SERVICE_ID --output text --confirm
}

# 최근 로그 확인
recent_logs() {
    echo -e "${GREEN}📋 최근 로그 확인${NC}"

    echo -e "${BLUE}--- API 서버 최근 20개 로그 ---${NC}"
    render logs --limit 20 -r $API_SERVICE_ID --output text --confirm
}

# 에러 로그만 확인
error_logs() {
    echo -e "${RED}🚨 에러 로그 확인${NC}"

    echo -e "${BLUE}--- API 서버 에러 로그 ---${NC}"
    render logs --level error --limit 50 -r $API_SERVICE_ID --output text --confirm || echo "에러 로그가 없습니다."
}

# 메인 실행 로직
main() {
    check_api_key

    case "${1:-tail}" in
        "api")
            api_logs
            ;;
        "recent")
            recent_logs
            ;;
        "errors")
            error_logs
            ;;
        "tail")
            api_logs  # 기본값: API 서버 실시간 로그
            ;;
        "-h"|"--help"|"help")
            usage
            ;;
        *)
            echo -e "${RED}❌ 알 수 없는 옵션: $1${NC}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"
