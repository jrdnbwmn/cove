class LoopsContactBackfillJob < ApplicationJob
  BATCH_SIZE = 100
  THROTTLE_INTERVAL = 0.2

  retry_on LoopsClient::RateLimit, LoopsClient::InternalError,
    Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
    Errno::ECONNRESET, wait: :polynomially_longer

  def perform(cursor = nil)
    build_synchronizer.ensure_backfill_ready!

    user_ids = candidate_ids(cursor)
    log(event: "loops.contact_sync.backfill_started", cursor:, candidate_count: user_ids.size)

    if user_ids.empty?
      log(event: "loops.contact_sync.backfill_completed", cursor:)
      return
    end

    throttler = -> { pause(THROTTLE_INTERVAL) }
    synchronizer = build_synchronizer(client: build_client(throttler:))

    user_ids.each do |user_id|
      user = User.find_by(id: user_id)
      synchronizer.sync(user, intent: :opt_in) if user
      log(event: "loops.contact_sync.backfill_progress", user_id:)
    end

    if user_ids.size == BATCH_SIZE
      self.class.perform_later(user_ids.last)
      log(event: "loops.contact_sync.backfill_enqueued", cursor: user_ids.last)
    else
      log(event: "loops.contact_sync.backfill_completed", cursor: user_ids.last)
    end
  end

  private

  def candidate_ids(cursor)
    users = User.marketing_subscribed
    users = users.where("id > ?", cursor) if cursor.present?
    users.order(:id).limit(BATCH_SIZE).pluck(:id)
  end

  def build_synchronizer(client: nil)
    LoopsContactSynchronizer.new(client:)
  end

  def build_client(throttler:)
    LoopsClient.client(throttler:)
  end

  def pause(seconds)
    sleep(seconds)
  end

  def log(**attributes)
    Rails.logger.info(attributes)
  end
end
