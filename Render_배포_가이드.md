# Render.com 배포 가이드

이 문서는 Render.com에서 개발(Staging) 환경과 프로덕션 환경을 분리하여 배포하는 방법을 설명합니다.

## 환경 구성

본 프로젝트는 다음 환경을 지원합니다:

- **개발(Development)**: 로컬 개발 환경
- **테스트(Test)**: 테스트를 위한 환경
- **스테이징(Staging)**: 개발 버전을 배포하는 환경
- **프로덕션(Production)**: 안정화된 버전을 배포하는 환경

## Git 브랜치 전략

- **main**: 안정화된 프로덕션 코드 (프로덕션 환경 배포용)
- **develop**: 개발 중인 코드 (스테이징 환경 배포용)
- **feature/xxx**: 새로운 기능 개발용 브랜치
- **hotfix/xxx**: 긴급 버그 수정용 브랜치

## Render.com 서비스 설정

### 1. 프로덕션 서비스 설정

1. 서비스 이름: `talkk-api-prod`
2. GitHub 연결: `main` 브랜치
3. 환경 변수:
   - `RAILS_ENV`: `production`
   - `RAILS_MASTER_KEY`: 프로덕션용 마스터 키

### 2. 스테이징 서비스 설정

1. 서비스 이름: `talkk-api-staging`
2. GitHub 연결: `develop` 브랜치
3. 환경 변수:
   - `RAILS_ENV`: `staging`
   - `RAILS_MASTER_KEY`: 스테이징용 마스터 키 (프로덕션과 다른 값 사용)

## 환경별 설정 파일

- `config/environments/production.rb`: 프로덕션 환경 설정
- `config/environments/staging.rb`: 스테이징 환경 설정
- `config/database.yml`: 환경별 데이터베이스 설정

## 배포 프로세스

### 새 기능 개발 및 배포 과정

1. `develop` 브랜치에서 `feature/xxx` 브랜치 생성
2. 기능 개발 완료 후 `develop` 브랜치로 머지
3. `develop` 브랜치가 자동으로 스테이징 환경에 배포됨
4. 스테이징 환경에서 테스트 및 검증
5. 안정화되면 `develop` 브랜치를 `main` 브랜치로 머지
6. `main` 브랜치가 자동으로 프로덕션 환경에 배포됨

### 긴급 수정 과정

1. `main` 브랜치에서 `hotfix/xxx` 브랜치 생성
2. 버그 수정 완료 후 `main` 브랜치로 머지
3. `main` 브랜치가 자동으로 프로덕션 환경에 배포됨
4. `hotfix/xxx` 브랜치를 `develop` 브랜치에도 머지

## 모니터링 및 로깅

- 프로덕션 환경: 로그 레벨 `warn`으로 설정하여 중요 정보만 로깅
- 스테이징 환경: 로그 레벨 `info`로 설정하여 더 많은 정보 로깅

## 문제 해결

### 일반적인 배포 오류

1. **Assets 관련 오류**: API 모드에서는 asset pipeline 관련 설정 비활성화
2. **콜백 메서드 오류**: Rails 버전 변경 시 콜백 메서드 호환성 확인
3. **데이터베이스 연결 오류**: 환경 변수와 데이터베이스 설정 확인 