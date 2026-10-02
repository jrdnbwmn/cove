class LoopsContactSyncJob < ApplicationJob
  include LoopsRetryable

  def perform(user_id, intent, previously_consented: nil)
    user = User.find_by(id: user_id)
    return unless user

    LoopsContactSynchronizer.new.sync(user, intent: intent, previously_consented: previously_consented)

    # AIDEV-NOTE: (a) enqueue happens after `sync` returns without raising, so a
    # failed upsert (which raises and is retried by LoopsRetryable) never
    # produces an event against a contact that does not exist. (b) `sync` also
    # returns nil for its own gated/no-op paths (env/config gate, stale
    # consent), and that is deliberately not distinguished here from a real
    # write — LoopsEventEmitter independently re-checks the same environment
    # gate and consent predicate, so an enqueue after a no-op sync ends in a
    # no-op emit rather than a wrong send.
    if intent.to_sym == :opt_in && user.marketing_opt_in_source == "registration"
      LoopsEventJob.perform_later(user.id, "user_signed_up")
    end
  end
end
