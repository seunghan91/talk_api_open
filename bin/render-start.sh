#!/bin/bash

# Render 서버에서 Rails 앱 시작 스크립트

# Log helper function
log() {
  echo "[render-start] $(date -u +"%Y-%m-%d %H:%M:%S UTC"): $1"
}

# Make the script exit if any command fails
set -e

# Log environment info
log "Starting Render deployment script"
log "Ruby version: $(ruby --version)"
log "Rails environment: $RAILS_ENV"

# Check Redis Connection (with retry logic)
MAX_REDIS_RETRIES=10
REDIS_RETRY_INTERVAL=5
REDIS_CONNECTED=false

log "Checking Redis connection..."
for i in $(seq 1 $MAX_REDIS_RETRIES); do
  if [[ -z "$REDIS_URL" ]]; then
    log "WARNING: REDIS_URL is not set! Using default localhost URL."
    REDIS_URL="redis://localhost:6379/0"
  fi
  
  # Extract host and port from REDIS_URL
  REDIS_HOST=$(echo $REDIS_URL | sed -E 's/^redis:\/\/(([^:@]+)(:([^@]+))?@)?([^:]+)(:[0-9]+)?\/.*$/\5/')
  REDIS_PORT=$(echo $REDIS_URL | sed -E 's/^redis:\/\/(([^:@]+)(:([^@]+))?@)?([^:]+):?([0-9]+)?\/.*$/\6/')
  REDIS_PORT=${REDIS_PORT:-6379}  # Default to 6379 if port not specified
  
  log "Trying to connect to Redis at $REDIS_HOST:$REDIS_PORT (attempt $i of $MAX_REDIS_RETRIES)..."
  
  # Use redis-cli to check connectivity with a 3-second timeout
  if timeout 3 redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping > /dev/null 2>&1; then
    log "Successfully connected to Redis!"
    REDIS_CONNECTED=true
    break
  else
    log "Failed to connect to Redis. Retrying in $REDIS_RETRY_INTERVAL seconds..."
    sleep $REDIS_RETRY_INTERVAL
  fi
done

if [[ "$REDIS_CONNECTED" != "true" ]]; then
  log "ERROR: Failed to connect to Redis after $MAX_REDIS_RETRIES attempts. Continuing anyway, but caching might not work properly."
fi

# Database setup
log "Preparing database..."
bundle exec rails db:reset db:create db:migrate db:prepare

# Check if database was seeded
if [[ -z $(bundle exec rails runner "puts User.count > 0") ]]; then
  log "Seeding database with initial data..."
  bundle exec rails db:seed
else
  log "Database already has data, skipping seed"
fi

# Start the server
log "Starting Rails server..."
bundle exec rails server -b 0.0.0.0 -p $PORT 