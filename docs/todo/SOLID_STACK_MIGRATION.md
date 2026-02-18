# Talkk API - Solid Stack 마이그레이션 설계서

**작성일**: 2026-02-17
**현재 버전**: Rails 8.1.0
**참조 구현**: keeps-backend (100% Solid Stack 완성)
**현재 완성도**: 100% ✅
**목표 완성도**: 100%
**완료일**: 2026-02-17

---

## 1. 현재 상태 진단

### 1.1 Gemfile (✅ Solid Stack 설치됨)
```ruby
gem "solid_queue", "~> 1.1"   # line 40
gem "solid_cache", "~> 1.0"   # line 41
gem "solid_cable", "~> 3.0"   # line 42
```
- `gem "redis", "~> 5.0"` (line 37) 도 존재 → "caching and health check connectivity" 용도 명시

### 1.2 config/database.yml (⚠️ Production만 Multi-DB, Dev/Test 단일)
```yaml
# development: 단일 DB
development:
  <<: *default
  database: talkk_api_development

# production: Multi-DB ✅ (이미 설정됨!)
production:
  primary:
    <<: *default
    url: <%= ENV['DATABASE_URL'] %>
    database: talkk_api_production
  queue:
    <<: *default
    url: <%= ENV['DATABASE_URL'] %>
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    url: <%= ENV['DATABASE_URL'] %>
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    url: <%= ENV['DATABASE_URL'] %>
    migrations_paths: db/cable_migrate
```
- **좋은 점**: production Multi-DB 이미 완성
- **문제**: development/test에 Multi-DB 없음 → 개발 환경에서 Solid Stack 테스트 불가

### 1.3 config/environments/production.rb (✅ 대부분 설정됨)
```ruby
config.cache_store = :solid_cache_store        # line 80 ✅
config.active_job.queue_adapter = :solid_queue  # line 86 ✅
config.solid_queue.connects_to = { database: { writing: :queue } }  # line 87 ✅
```
- Production 설정 완벽

### 1.4 config/environments/development.rb (❌ Solid 미설정)
```ruby
# line 22-29: 기본 memory_store / null_store
if Rails.root.join("tmp/caching-dev.txt").exist?
  config.cache_store = :memory_store
else
  config.cache_store = :null_store
end
```
- `active_job.queue_adapter` 미설정 (기본 async)
- `solid_queue.connects_to` 미설정

### 1.5 config/cable.yml (✅ Solid Cable 설정됨)
```yaml
production:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

### 1.6 config/cache.yml (✅ 존재)
```yaml
production:
  database: cache
```
- development/test에는 `database:` 미지정 (기본 ActiveRecord connection 사용)

### 1.7 config/queue.yml (✅ 존재, 정상)

### 1.8 config/puma.rb (❌ Solid Queue plugin 없음)
- Puma 7.x 설정이나 `plugin :solid_queue` 없음
- production에서 cluster mode + preload_app 사용

### 1.9 bin/jobs (✅ 존재)

---

## 2. 마이그레이션 계획

이 프로젝트는 **70% 완성 상태**이므로 나머지 30%만 채우면 됩니다.

### Phase 1: Development/Test Multi-DB 설정

#### database.yml 수정
```yaml
development:
  primary:
    <<: *default
    database: talkk_api_development
  cache:
    <<: *default
    database: talkk_api_cache_development
    migrations_paths: db/cache_migrate
  queue:
    <<: *default
    database: talkk_api_queue_development
    migrations_paths: db/queue_migrate
  cable:
    <<: *default
    database: talkk_api_cable_development
    migrations_paths: db/cable_migrate

test:
  primary:
    <<: *default
    database: talkk_api_test
  cache:
    <<: *default
    database: talkk_api_cache_test
    migrations_paths: db/cache_migrate
  queue:
    <<: *default
    database: talkk_api_queue_test
    migrations_paths: db/queue_migrate
  cable:
    <<: *default
    database: talkk_api_cable_test
    migrations_paths: db/cable_migrate

# staging은 production과 동일 패턴 적용
staging:
  primary:
    <<: *default
    url: <%= ENV['DATABASE_URL'] %>
    database: talkk_api_staging
  queue:
    <<: *default
    url: <%= ENV['DATABASE_URL'] %>
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    url: <%= ENV['DATABASE_URL'] %>
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    url: <%= ENV['DATABASE_URL'] %>
    migrations_paths: db/cable_migrate

# production 유지 (이미 올바름)
```

### Phase 2: Development 환경 Solid Stack 활성화

#### development.rb 수정
```ruby
# 변경 전 (line 22-29)
if Rails.root.join("tmp/caching-dev.txt").exist?
  config.cache_store = :memory_store
  config.public_file_server.headers = { "Cache-Control" => "public, max-age=#{2.days.to_i}" }
else
  config.action_controller.perform_caching = false
  config.cache_store = :null_store
end

# 변경 후
if Rails.root.join("tmp/caching-dev.txt").exist?
  config.action_controller.perform_caching = true
  config.action_controller.enable_fragment_cache_logging = true
  config.public_file_server.headers = { "Cache-Control" => "public, max-age=#{2.days.to_i}" }
else
  config.action_controller.perform_caching = false
end

# Solid Cache (development)
config.cache_store = :solid_cache_store

# Solid Queue (development)
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

### Phase 3: Cache.yml 개선

#### config/cache.yml 수정
```yaml
default: &default
  store_options:
    max_size: <%= 256.megabytes %>
    namespace: <%= Rails.env %>

development:
  database: cache
  <<: *default

test:
  database: cache
  <<: *default

production:
  database: cache
  <<: *default
```
- development/test에 `database: cache` 추가 (Multi-DB 매핑)

### Phase 4: Puma Solid Queue Plugin 추가

#### config/puma.rb 수정
```ruby
# 기존 코드 끝 부분 (line 120 이후)에 추가:

# Run the Solid Queue supervisor inside of Puma for single-server deployments
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
```

**참고**: Talkk는 production에서 cluster mode(`workers`, `preload_app!`)를 사용하므로 Solid Queue를 별도 프로세스(`bin/jobs`)로 실행하는 것이 더 적합할 수 있음. Plugin은 single-server 배포용 옵션으로 추가.

### Phase 5: 데이터베이스 생성 및 마이그레이션

```bash
# development 환경
bin/rails db:create    # 새 cache/queue/cable DB 생성
bin/rails db:prepare   # schema 로드

# 기존 primary DB의 solid_queue 테이블 확인
# (이미 production에서 사용 중이므로 테이블이 있을 수 있음)
```

---

## 3. 실행 순서 체크리스트

- [x] **Step 1**: `config/database.yml` dev/test/staging Multi-DB 추가 ✅ (2026-02-17)
- [x] **Step 2**: `config/environments/development.rb` Solid Stack 설정 추가 ✅ (2026-02-17)
- [x] **Step 3**: `config/cache.yml` dev/test에 `database: cache` 추가 ✅ (2026-02-17)
- [x] **Step 4**: `config/puma.rb`에 `plugin :solid_queue` 추가 ✅ (2026-02-17)
- [x] **Step 5**: `bin/rails db:create` (dev 환경 새 DB) ✅ (2026-02-17)
- [x] **Step 6**: `bin/rails db:prepare` ✅ (2026-02-17)
- [x] **Step 7**: 개발 서버 테스트 ✅ (2026-02-17)
- [x] **Step 8**: Cache 동작 검증 ✅ (2026-02-17)
- [x] **Step 9**: Queue 동작 검증 ✅ (2026-02-17)
- [ ] **Step 10**: Redis 의존성 정리 검토 (선택, 미진행)

### 검증 결과 (2026-02-17)
- `spec/config/solid_stack_migration_spec.rb` 작성 → **4 examples, 0 failures**
- development.rb: `solid_cache_store` + `solid_queue` + `connects_to` 설정 완료
- cache.yml: dev/test에 `database: cache` 추가 완료
- puma.rb: `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]` 추가 완료
- database.yml: dev/test/staging Multi-DB 설정 완료

---

## 4. 위험 요소 및 주의사항

### 4.1 Rails 8.1.0 특이사항
- 이 프로젝트는 Rails 8.1.0으로 다른 프로젝트보다 최신
- Solid Queue/Cache/Cable gem 버전이 Rails 8.1과 호환되는지 확인
- `~> 1.1` (solid_queue), `~> 1.0` (solid_cache), `~> 3.0` (solid_cable) → 최신 버전과 호환

### 4.2 Puma Cluster Mode + Solid Queue
- Production에서 `preload_app!` + `workers` 사용
- Solid Queue plugin은 cluster mode에서도 동작하나, 별도 `bin/jobs` 프로세스 권장
- Render에서 별도 Worker 서비스로 `bin/jobs` 실행 고려

### 4.3 기존 Production 데이터
- Production에서 이미 Solid Queue/Cache/Cable 사용 중
- Development 환경만 맞추면 되므로 production 리스크 없음

### 4.4 Staging 환경
- `staging:` 설정에도 Multi-DB 적용 필요
- staging이 별도 Render 인스턴스인 경우 `DATABASE_URL` 공유 확인

### 4.5 Redis 제거 가능성
- Gemfile 주석: "Redis kept for caching and health check connectivity"
- Solid Cache로 전환 완료 시 Redis caching 불필요
- Health check에서 Redis 연결 확인하는 코드가 있는지 검사 필요
```bash
grep -rn "Redis\|redis" app/ config/initializers/ lib/
```

---

## 5. 최종 설정 검증

```bash
# 1. Development DB 연결 확인
bin/rails runner "puts ActiveRecord::Base.connection_db_config.database"
bin/rails runner "puts SolidQueue::Job.count"
bin/rails runner "puts SolidCache::Entry.count"

# 2. Cache 동작 확인
bin/rails runner "Rails.cache.write('test', 'solid'); puts Rails.cache.read('test')"

# 3. Queue 동작 확인
bin/rails runner "ApplicationJob.perform_later; puts 'Job enqueued'"
bin/jobs  # 별도 터미널

# 4. 환경별 설정 확인
RAILS_ENV=development bin/rails runner "puts Rails.configuration.cache_store"
RAILS_ENV=production bin/rails runner "puts Rails.configuration.cache_store"
```

---

## 6. 요약

| 항목 | 현재 | 목표 | 난이도 |
|------|------|------|--------|
| Production 설정 | ✅ 완료 | 유지 | - |
| Dev/Test Multi-DB | ✅ 완료 | ✅ | - |
| Dev cache_store | ✅ solid_cache | ✅ solid_cache | - |
| Dev queue_adapter | ✅ solid_queue | ✅ solid_queue | - |
| Puma plugin | ✅ 완료 | ✅ | - |
| cache.yml | ✅ 전체 | ✅ 전체 | - |

**상태**: ✅ 마이그레이션 완료 (2026-02-17), RSpec 4/4 통과
