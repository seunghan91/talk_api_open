#!/usr/bin/env bash

# Render 서버에서 Rails 앱 시작 스크립트

# 실행 로그 출력
echo "====> 🚀 Render 시작 스크립트 실행..."

# DB 초기화 및 재구성 명령어 (강제 수행)
echo "====> 🗄️ Dropping, Creating, Migrating, and Seeding database (production)..."
DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rails db:drop RAILS_ENV=production
bundle exec rails db:create RAILS_ENV=production
bundle exec rails db:migrate RAILS_ENV=production
bundle exec rails db:seed RAILS_ENV=production

# Sidekiq과 Redis 상태 확인
echo "====> 🔄 Redis 연결 확인 중..."
if bundle exec rails runner "Redis.new(url: ENV['REDIS_URL']).ping"; then
  echo "====> ✅ Redis 연결 성공"
else
  echo "====> ⚠️ Redis 연결 실패 - Redis URL 설정을 확인하세요"
  echo "====> Redis URL: $REDIS_URL"
fi

# Rails 서버 실행
echo "====> 🌐 Rails 서버 시작 ($PORT 포트에서 수신 대기 중)..."
bundle exec rails server -b 0.0.0.0 -p $PORT 