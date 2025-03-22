# app/workers/expire_broadcasts_worker.rb
class ExpireBroadcastsWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 0

  def perform
    # 만료된 브로드캐스트 비활성화
    expired_broadcasts = Broadcast.where("expired_at < ?", Time.current).where(active: true)
    count = expired_broadcasts.count

    # 모두 한번에 업데이트
    expired_broadcasts.update_all(active: false)

    # 캐시 무효화
    Rails.cache.delete("broadcasts-recent")

    # 로깅
    Rails.logger.info "#{count}개의 브로드캐스트가 만료되어 비활성화되었습니다."
  end
end
