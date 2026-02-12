# Procfile
web: bundle exec puma -C config/puma.rb
release: bundle exec rails db:migrate
worker: bundle exec rake solid_queue:start