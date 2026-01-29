# Talk API Rails Upgrade Plan

## Executive Summary

This document outlines a comprehensive upgrade strategy for the Talk API backend from **Rails 7.1 / Ruby 3.3.0** to **Rails 8.1 / Ruby 3.4**.

---

## 1. Current State Assessment

### 1.1 Version Summary

| Component | Current Version | Target Version | Gap |
|-----------|-----------------|----------------|-----|
| Ruby | 3.3.0 | 3.4.x | Minor upgrade |
| Rails | 7.1.5.1 | 8.1.2 | Major upgrade |
| PostgreSQL | ~> 1.1 (pg 1.5.9) | Latest (1.6.x) | Minor upgrade |
| Sidekiq | 7.3.9 | 8.1.0 | Major upgrade |
| Puma | 6.6.0 | 7.2.0 | Major upgrade |
| Redis | 4.8.1 | 5.4.1 | Major upgrade |

### 1.2 Project Architecture

**Application Type**: API-only Rails application (with admin dashboard)
**Database**: PostgreSQL with Active Record Encryption
**Background Jobs**: Sidekiq with Redis
**Authentication**: JWT-based
**File Storage**: Active Storage
**API Documentation**: Rswag (Swagger/OpenAPI)
**Error Tracking**: Sentry
**Deployment**: Render.com

### 1.3 Current Structure

```
app/
├── controllers/          # 31 controller files
│   ├── api/v1/          # Main API endpoints
│   ├── admin/           # Admin dashboard
│   └── ...
├── models/              # 15 models
├── services/            # 20 service classes (SOLID architecture)
├── repositories/        # 5 repository classes
├── forms/               # 2 form objects
├── commands/            # 4 command objects
├── workers/             # 5 Sidekiq workers
├── events/              # 4 event classes
├── jobs/                # 2 Active Job classes
└── lib/                 # Auth utilities

db/migrate/              # 40 migration files
spec/                    # 47 spec files
```

### 1.4 Key Dependencies Status

#### Critical Dependencies (Major Upgrades Required)

| Gem | Current | Latest | Breaking Changes |
|-----|---------|--------|------------------|
| rails | 7.1.5.1 | 8.1.2 | Yes - See Section 3 |
| sidekiq | 7.3.9 | 8.1.0 | Yes - Configuration changes |
| puma | 6.6.0 | 7.2.0 | Yes - Configuration format |
| redis | 4.8.1 | 5.4.1 | Yes - Client API changes |
| jwt | 2.10.1 | 3.1.2 | Yes - Algorithm requirements |
| sentry-ruby | 5.23.0 | 6.3.0 | Yes - Initialization changes |
| rack-cors | 2.0.2 | 3.0.0 | Minor - Configuration |
| rspec-rails | 7.1.1 | 8.0.2 | Minor - Rails 8 support |

#### Pinned Dependencies (Need Review)

| Gem | Current | Reason | Action |
|-----|---------|--------|--------|
| nokogiri | ~> 1.16.0 | Compatibility | Update to latest |
| ffi | ~> 1.15.5 | Compatibility | Update to 1.17.x |
| redis-rails | ~> 5.0 | Deprecated | Remove, use built-in |
| annotate | 3.2.0 | Rails 8 support | Update or replace |

### 1.5 Code Patterns Analysis

**Positive Patterns**:
- SOLID principles applied (Service Objects, Repositories, Commands)
- Strategy pattern for notifications
- Form Objects for validation
- Event-driven architecture foundation
- Structured error handling

**Areas Needing Attention**:
- `config.load_defaults 7.0` - Should be 7.1, then 8.0
- `config.api_only = false` - Consider separation
- Mixed route patterns (legacy + v1)
- Some deprecated enum syntax usage
- redis-rails gem is deprecated

---

## 2. Target Versions

### 2.1 Primary Targets

| Component | Target Version | Release Date |
|-----------|----------------|--------------|
| Ruby | 3.4.1 | December 2024 |
| Rails | 8.1.2 | January 2025 |
| Bundler | 2.7.x | Latest stable |

### 2.2 Secondary Targets (Gems)

```ruby
# Target Gemfile versions
gem "rails", "~> 8.1.0"
gem "pg", "~> 1.6"
gem "puma", "~> 7.0"
gem "sidekiq", "~> 8.0"
gem "redis", "~> 5.0"
gem "jwt", "~> 3.0"
gem "bcrypt", "~> 3.1.20"
gem "rack-cors", "~> 3.0"
gem "sentry-rails", "~> 6.0"
gem "sentry-ruby", "~> 6.0"
gem "rspec-rails", "~> 8.0"
```

### 2.3 Ruby 3.4 New Features to Leverage

- `it` as block parameter (anonymous block parameter)
- Prism parser as default
- Improved YJIT performance
- Socket library improvements
- Better error messages

### 2.4 Rails 8.1 New Features

- Solid Queue as default job backend (optional, can keep Sidekiq)
- Solid Cache for caching
- Solid Cable for WebSockets
- Thruster as proxy server
- Kamal 2 for deployment
- Propshaft as default asset pipeline
- Authentication generator improvements
- Active Record improvements

---

## 3. Breaking Changes to Address

### 3.1 Rails 7.1 to 7.2 Changes

1. **Default Configuration Updates**
   ```ruby
   # config/application.rb
   # Change from:
   config.load_defaults 7.0
   # To:
   config.load_defaults 7.1
   ```

2. **Active Record Enum Changes**
   ```ruby
   # Current (deprecated syntax):
   enum :status, { active: 0, suspended: 1, banned: 2 }, prefix: true

   # Rails 7.2+ preferred:
   enum :status, { active: 0, suspended: 1, banned: 2 }, prefix: true, validate: true
   ```

3. **Action Controller Parameters**
   - Stricter parameter filtering by default
   - Review all `params.permit` calls

### 3.2 Rails 7.2 to 8.0 Changes

1. **Minimum Ruby Version**: Ruby 3.2+ required (current 3.3 is compatible)

2. **Application Configuration**
   ```ruby
   # New default: config.eager_load_paths includes lib/
   config.autoload_lib(ignore: %w[assets tasks])  # Enable this
   ```

3. **Active Storage Changes**
   - New `has_one_attached` and `has_many_attached` options
   - Direct upload improvements

4. **Database Configuration**
   - `config.active_record.default_timezone` changes
   - New connection handling

### 3.3 Rails 8.0 to 8.1 Changes

1. **Solid Queue Integration** (Optional)
   - Can replace Sidekiq or run alongside
   - Database-backed job queue

2. **New Defaults**
   ```ruby
   config.load_defaults 8.1
   ```

### 3.4 Gem-Specific Breaking Changes

#### Sidekiq 7 to 8

```ruby
# config/initializers/sidekiq.rb changes:

# Old (v7):
Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.error_handlers << proc { |ex, ctx| ... }
end

# New (v8):
Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  # error_handlers moved to exception_handlers
  config.exception_handlers << proc { |ex, ctx, msg| ... }
end
```

#### Redis 4 to 5

```ruby
# Old (v4):
redis = Redis.new(url: ENV['REDIS_URL'])

# New (v5):
redis = Redis.new(url: ENV['REDIS_URL'])
# Most APIs remain compatible, but some deprecated methods removed
# Review redis-rails usage (deprecated gem)
```

#### JWT 2 to 3

```ruby
# Old (v2):
JWT.encode(payload, secret)
JWT.decode(token, secret)

# New (v3):
JWT.encode(payload, secret, 'HS256')  # Algorithm now required
JWT.decode(token, secret, true, algorithm: 'HS256')
```

#### Puma 6 to 7

```ruby
# config/puma.rb needs review
# Threading model changes
# New cluster mode options
```

---

## 4. Step-by-Step Upgrade Plan

### Phase 0: Pre-Upgrade Preparation (1-2 days)

#### 0.1 Create Upgrade Branch
```bash
git checkout -b feature/rails-8.1-upgrade
```

#### 0.2 Ensure Test Suite Passes
```bash
bundle exec rspec
# Current: 47 spec files - ensure all green
```

#### 0.3 Update Bundler
```bash
gem install bundler -v 2.7.0
bundle update --bundler
```

#### 0.4 Remove Deprecated Gems
```ruby
# Gemfile - Remove:
gem "redis-rails", "~> 5.0"  # Deprecated, use built-in Rails cache

# Replace with:
# (Rails has built-in redis cache store)
```

#### 0.5 Update Pinned Dependencies First
```ruby
# Gemfile - Update these first:
gem "nokogiri", "~> 1.18"
gem "ffi", "~> 1.17"
```

### Phase 1: Ruby 3.4 Upgrade (1 day)

#### 1.1 Update Ruby Version
```ruby
# .ruby-version
3.4.1

# Gemfile
ruby "3.4.1"
```

#### 1.2 Install Ruby 3.4
```bash
# Using rbenv:
rbenv install 3.4.1
rbenv local 3.4.1

# Or using asdf:
asdf install ruby 3.4.1
asdf local ruby 3.4.1
```

#### 1.3 Update Bundle
```bash
bundle install
bundle exec rspec  # Verify tests pass
```

### Phase 2: Rails 7.2 Upgrade (1-2 days)

#### 2.1 Update Gemfile
```ruby
gem "rails", "~> 7.2.0"
```

#### 2.2 Run Update Task
```bash
bundle update rails
bin/rails app:update
```

#### 2.3 Review Generated Diffs
- `config/application.rb` changes
- `config/environments/*.rb` changes
- New initializers

#### 2.4 Update load_defaults
```ruby
# config/application.rb
config.load_defaults 7.2
```

#### 2.5 Address Deprecations
```bash
RAILS_ENV=test bundle exec rspec 2>&1 | grep -i deprecat
```

### Phase 3: Rails 8.0 Upgrade (2-3 days)

#### 3.1 Update Gemfile
```ruby
gem "rails", "~> 8.0.0"
```

#### 3.2 Run Update Task
```bash
bundle update rails
bin/rails app:update
```

#### 3.3 Update Configuration
```ruby
# config/application.rb
config.load_defaults 8.0

# Enable autoload_lib
config.autoload_lib(ignore: %w[assets tasks])
```

#### 3.4 Update Dependencies for Rails 8
```ruby
# Gemfile
gem "rspec-rails", "~> 8.0"
gem "factory_bot_rails", "~> 6.5"
```

### Phase 4: Rails 8.1 Upgrade (1-2 days)

#### 4.1 Update Gemfile
```ruby
gem "rails", "~> 8.1.0"
```

#### 4.2 Run Update Task
```bash
bundle update rails
bin/rails app:update
```

#### 4.3 Update Configuration
```ruby
# config/application.rb
config.load_defaults 8.1
```

### Phase 5: Supporting Gem Upgrades (2-3 days)

#### 5.1 Sidekiq 8 Upgrade
```ruby
# Gemfile
gem "sidekiq", "~> 8.0"
```

```ruby
# config/initializers/sidekiq.rb - Update
Sidekiq.configure_server do |config|
  config.redis = { url: redis_url, ssl: is_external_url }

  # Update to exception_handlers
  config.exception_handlers << proc do |ex, ctx, msg|
    Rails.logger.error("Sidekiq error: #{ex.class} - #{msg}")
  end

  # death_handlers remain the same
  config.death_handlers << ->(job, ex) do
    # existing logic
  end
end
```

#### 5.2 Puma 7 Upgrade
```ruby
# Gemfile
gem "puma", "~> 7.0"
```

Review `config/puma.rb` for any deprecated options.

#### 5.3 Redis 5 Upgrade
```ruby
# Gemfile
gem "redis", "~> 5.0"
# Remove redis-rails entirely
```

Update Redis usage patterns:
```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
  expires_in: 1.day,
  error_handler: ->(method:, returning:, exception:) {
    Sentry.capture_exception(exception) if defined?(Sentry)
  }
}
```

#### 5.4 JWT 3 Upgrade
```ruby
# Gemfile
gem "jwt", "~> 3.0"
```

```ruby
# app/lib/auth_token.rb - Update
class AuthToken
  ALGORITHM = 'HS256'

  def self.encode(payload)
    JWT.encode(payload, secret_key, ALGORITHM)
  end

  def self.decode(token)
    JWT.decode(token, secret_key, true, algorithm: ALGORITHM).first
  end

  private

  def self.secret_key
    Rails.application.credentials.secret_key_base
  end
end
```

#### 5.5 Sentry 6 Upgrade
```ruby
# Gemfile
gem "sentry-ruby", "~> 6.0"
gem "sentry-rails", "~> 6.0"
```

```ruby
# config/initializers/sentry.rb - Review initialization
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1
end
```

### Phase 6: Code Updates (2-3 days)

#### 6.1 Update Enum Declarations
```ruby
# app/models/user.rb
# Add validation to enums
enum :gender, { unknown: 0, male: 1, female: 2 }, prefix: true, validate: true
enum :status, { active: 0, suspended: 1, banned: 2 }, prefix: true, validate: true
```

#### 6.2 Update Strong Parameters
Review all `params.permit` for stricter Rails 8 defaults.

#### 6.3 Update Active Storage Usage
Review attachments for new Rails 8 patterns.

#### 6.4 Update Cache Configuration
Remove redis-rails dependency, use Rails built-in redis cache store.

### Phase 7: Testing and Validation (3-5 days)

#### 7.1 Run Full Test Suite
```bash
bundle exec rspec
```

#### 7.2 Run Security Scan
```bash
bundle exec brakeman
bundle audit check --update
```

#### 7.3 Run Deprecation Check
```bash
RAILS_ENV=test bundle exec rspec 2>&1 | grep -i deprecat
```

#### 7.4 Performance Testing
- Run load tests
- Check memory usage
- Monitor response times

### Phase 8: Deployment (1-2 days)

#### 8.1 Staging Deployment
- Deploy to staging environment
- Run smoke tests
- Monitor for 24-48 hours

#### 8.2 Production Deployment
- Schedule maintenance window
- Deploy with rollback plan
- Monitor closely for first 72 hours

---

## 5. Testing Strategy

### 5.1 Current Test Coverage

| Category | Files | Status |
|----------|-------|--------|
| Model specs | ~15 | Review needed |
| Controller specs | ~10 | Review needed |
| Service specs | ~15 | Good |
| Request specs | ~5 | Expand |
| System specs | 0 | Consider adding |

### 5.2 Pre-Upgrade Testing

1. **Ensure all existing tests pass**
   ```bash
   bundle exec rspec --format documentation
   ```

2. **Check test coverage**
   ```bash
   # Add simplecov if not present
   # Aim for >80% coverage before upgrade
   ```

3. **Run static analysis**
   ```bash
   bundle exec rubocop
   bundle exec brakeman
   ```

### 5.3 During Upgrade Testing

Run tests after each phase:
```bash
# After each major change
bundle exec rspec

# Quick smoke test
bundle exec rspec spec/requests --tag smoke
```

### 5.4 Post-Upgrade Testing

1. **Full regression test**
2. **API endpoint testing with actual client**
3. **Background job testing**
4. **Performance benchmarking**

### 5.5 Critical Test Scenarios

| Scenario | Priority | Type |
|----------|----------|------|
| User authentication flow | Critical | Request |
| Broadcast creation | Critical | Request |
| Message sending | Critical | Request |
| Push notification delivery | High | Worker |
| Wallet transactions | High | Service |
| File uploads (Active Storage) | High | Request |

---

## 6. Rollback Plan

### 6.1 Version Control Strategy

```bash
# Tag current production state
git tag v1.0.0-rails-7.1 -m "Last stable Rails 7.1 release"

# Create rollback branch
git checkout -b rollback/rails-7.1
```

### 6.2 Database Rollback

- No destructive migrations in upgrade
- Test `rails db:rollback` for new migrations

### 6.3 Deployment Rollback

```bash
# Render.com - Deploy previous commit
# Or use blue-green deployment
```

### 6.4 Rollback Triggers

- Error rate > 1% increase
- Response time > 200ms increase
- Critical feature failure
- Database connection issues

---

## 7. Risk Assessment

### 7.1 High Risk Areas

| Area | Risk | Mitigation |
|------|------|------------|
| JWT authentication | Breaking API | Thorough testing, version algorithm |
| Sidekiq jobs | Job failures | Gradual rollout, monitoring |
| Redis connections | Connection issues | Connection pool testing |
| Active Storage | File access issues | Pre-deployment file access test |

### 7.2 Medium Risk Areas

| Area | Risk | Mitigation |
|------|------|------------|
| API responses | Format changes | API contract tests |
| Cache behavior | Cache misses | Clear cache before deployment |
| Enum changes | Validation errors | Gradual rollout |

### 7.3 Low Risk Areas

| Area | Risk | Mitigation |
|------|------|------------|
| Test suite | Minor adjustments | RSpec 8 compatibility |
| Documentation | Minor updates | Post-upgrade updates |

---

## 8. Timeline Summary

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 0: Preparation | 1-2 days | None |
| Phase 1: Ruby 3.4 | 1 day | Phase 0 |
| Phase 2: Rails 7.2 | 1-2 days | Phase 1 |
| Phase 3: Rails 8.0 | 2-3 days | Phase 2 |
| Phase 4: Rails 8.1 | 1-2 days | Phase 3 |
| Phase 5: Gem Updates | 2-3 days | Phase 4 |
| Phase 6: Code Updates | 2-3 days | Phase 5 |
| Phase 7: Testing | 3-5 days | Phase 6 |
| Phase 8: Deployment | 1-2 days | Phase 7 |

**Total Estimated Duration**: 2-3 weeks

---

## 9. Post-Upgrade Improvements

### 9.1 Consider Adopting

- **Solid Queue**: Database-backed jobs (alternative to Sidekiq)
- **Solid Cache**: Database-backed caching
- **Kamal 2**: Deployment tool
- **Thruster**: HTTP/2 proxy server

### 9.2 Code Modernization

- Leverage Ruby 3.4 pattern matching
- Use `it` anonymous block parameter
- Adopt Rails 8.1 authentication patterns

### 9.3 Monitoring Updates

- Update Sentry SDK to v6
- Add Rails 8 performance monitoring
- Update error tracking patterns

---

## 10. Appendix

### A. Gemfile After Upgrade

```ruby
source "https://rubygems.org"

ruby "3.4.1"

gem "rails", "~> 8.1.0"
gem "pg", "~> 1.6"
gem "puma", "~> 7.0"

gem "bcrypt", "~> 3.1.20"
gem "bootsnap", require: false
gem "rack-cors", "~> 3.0"

gem "jwt", "~> 3.0"
gem "sidekiq", "~> 8.0"
gem "redis", "~> 5.0"

gem "logger"
gem "exponent-server-sdk"

gem "rswag-api"
gem "rswag-ui"
gem "rswag-specs"

gem "sentry-rails", "~> 6.0"
gem "sentry-ruby", "~> 6.0"

group :development, :test do
  gem "debug"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
  gem "faker"
end

group :development do
  gem "annotate"
end

group :test do
  gem "shoulda-matchers"
  gem "database_cleaner"
end

gem "kaminari"
gem "lograge"
```

### B. Configuration Changes Summary

1. `config/application.rb`: Update `load_defaults` to 8.1
2. `config/initializers/sidekiq.rb`: Update for Sidekiq 8
3. `app/lib/auth_token.rb`: Update for JWT 3
4. `config/environments/production.rb`: Update cache store
5. Remove `redis-rails` dependency

### C. Commands Quick Reference

```bash
# Update Ruby
rbenv install 3.4.1 && rbenv local 3.4.1

# Update Rails incrementally
bundle update rails
bin/rails app:update

# Run tests
bundle exec rspec

# Security check
bundle exec brakeman
bundle audit check --update

# Check deprecations
RAILS_ENV=test bundle exec rspec 2>&1 | grep -i deprecat
```

---

**Document Version**: 1.0
**Created**: January 29, 2026
**Last Updated**: January 29, 2026
**Author**: Rails Expert Agent
