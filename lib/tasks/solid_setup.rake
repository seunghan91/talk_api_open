namespace :solid do
  desc "Load Solid Stack schemas (queue, cache, cable) for secondary databases"
  task setup: :environment do
    %w[queue cache cable].each do |db_name|
      schema_file = Rails.root.join("db", "#{db_name}_schema.rb")
      next unless schema_file.exist?

      begin
        ActiveRecord::Base.establish_connection(db_name.to_sym)
        load schema_file
        puts "[solid:setup] #{db_name} schema loaded ✓"
      rescue ActiveRecord::StatementInvalid => e
        # 테이블이 이미 존재하는 경우 무시
        if e.message.include?("already exists")
          puts "[solid:setup] #{db_name} schema already exists, skipping ✓"
        else
          raise
        end
      rescue StandardError => e
        puts "[solid:setup] #{db_name} failed: #{e.message}"
      ensure
        ActiveRecord::Base.establish_connection(:primary)
      end
    end
  end
end
