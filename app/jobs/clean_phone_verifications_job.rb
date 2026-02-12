# app/jobs/clean_phone_verifications_job.rb
class CleanPhoneVerificationsJob < ApplicationJob
    queue_as :default

    def perform
      # 만료 후 30분 지난 인증 내역 삭제
      PhoneVerification.where("expires_at < ?", 30.minutes.ago).where(verified: false).destroy_all
    end
end
