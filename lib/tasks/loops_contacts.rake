namespace :loops do
  namespace :contacts do
    namespace :backfill do
      desc "Reports Loops contact-backfill readiness and consenting users without writes"
      task dry_run: :environment do
        config = Rails.application.config_for(:loops)

        puts "environment: #{Rails.env}"
        puts "production: #{Rails.env.production?}"
        puts "contact sync enabled: #{config.contact_sync_enabled == true}"
        puts "mailing list configured: #{config.contact_sync_mailing_list_id.present?}"
        puts "consenting users: #{User.marketing_subscribed.count}"
      end

      desc "Enqueues the first Loops contact-backfill batch"
      task enqueue: :environment do
        LoopsContactSynchronizer.new.ensure_backfill_ready!
        LoopsContactBackfillJob.perform_later(nil)

        puts "Loops contact backfill enqueued for environment: #{Rails.env}; initial cursor: nil"
      end
    end
  end
end
