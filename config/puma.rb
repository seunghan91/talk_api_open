# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Puma 7.x Configuration
# ======================

# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.

# Thread Configuration
# Puma 7 recommends explicit min/max thread settings
max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 3).to_i
min_threads_count = ENV.fetch("RAILS_MIN_THREADS", max_threads_count).to_i
threads min_threads_count, max_threads_count

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV", "development")

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Specifies the `bind` address that Puma will listen on.
# Use this for more control over the listening interface.
# bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"

# Cluster Mode Configuration (Production)
# ========================================
# Workers are forked web server processes. If using threads and workers together,
# the concurrency of the application would be max_threads * workers.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
#
# Puma 7 recommends using WEB_CONCURRENCY for worker count in production.
if ENV.fetch("RAILS_ENV", "development") == "production"
  # Use WEB_CONCURRENCY to set the number of workers
  # Recommended: 2-4 workers per CPU core
  workers ENV.fetch("WEB_CONCURRENCY", 2).to_i

  # Preload the application before forking workers for copy-on-write memory savings.
  # This is recommended for production but requires proper handling of connections.
  preload_app!

  # Code to run in the master process before forking workers
  before_fork do
    # Disconnect ActiveRecord before forking to prevent connection issues
    ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
  end

  # Code to run in each worker after forking
  on_worker_boot do
    # Re-establish ActiveRecord connection after forking
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end

  # Code to run when a worker is being shutdown
  on_worker_shutdown do
    # Clean up connections on worker shutdown
    ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
  end
end

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

# Puma 7 logging configuration
# Redirect stdout and stderr to log files in production
if ENV.fetch("RAILS_ENV", "development") == "production"
  stdout_redirect(
    ENV.fetch("PUMA_STDOUT_LOG", "/dev/stdout"),
    ENV.fetch("PUMA_STDERR_LOG", "/dev/stderr"),
    true  # append mode
  )
end

# Puma 7 connection draining
# Wait for active connections to finish before restarting/stopping
# Default is 60 seconds, adjust based on your longest request time
drain_on_shutdown ENV.fetch("PUMA_DRAIN_ON_SHUTDOWN", "true") == "true"
force_shutdown_after ENV.fetch("PUMA_FORCE_SHUTDOWN_AFTER", 30).to_i

# Puma 7 low latency mode (experimental)
# Reduces latency at the cost of higher CPU usage
# Uncomment if you need lower latency responses
# low_latency true

# Puma 7 queue requests
# Queue requests until a worker is available (cluster mode only)
# This is enabled by default in Puma 7
# queue_requests true

# Puma 7 persistent timeout
# Keep-alive timeout for persistent connections
# Default is 20 seconds
persistent_timeout ENV.fetch("PUMA_PERSISTENT_TIMEOUT", 20).to_i

# Puma 7 first data timeout
# Timeout waiting for first data from client
# Default is 30 seconds
first_data_timeout ENV.fetch("PUMA_FIRST_DATA_TIMEOUT", 30).to_i

# Run the Solid Queue supervisor inside Puma for single-server deployments.
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
