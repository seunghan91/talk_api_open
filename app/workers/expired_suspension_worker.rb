# app/workers/expired_suspension_worker.rb
class ExpiredSuspensionWorker
  include Sidekiq::Worker

  # 일일 1회 실행 (정지 종료 처리용)
  sidekiq_options queue: 'default', retry: 3

  def perform
    # 로그 기록
    logger.info("#{Time.current} : 만료된 계정 정지 해제 작업 시작")
    
    # 만료된 정지 처리
    count = UserSuspension.process_expired_suspensions
    
    # 결과 로깅
    logger.info("#{Time.current} : 만료된 계정 정지 해제 작업 완료 (#{count}건 처리됨)")
  end
end
