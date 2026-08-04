> Ticket: COV-54
> Branch: feature/cov-54-emit-lifecycle-events-to-loops

# Plan: Emit lifecycle events to Loops

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | `LoopsEventEmitter` service + tests | Master | |
| 2 | 1 | 1 | `LoopsEventJob` + tests | Clone | |
| 3 | 1 | 2 | Chain event enqueue off `LoopsContactSyncJob` + tests | Master | |
| 4 | 1 | 2 | End-to-end lifecycle coverage + AC verification | Clone | |

## Prerequisites

- Design: `docs/designs/cov-54-lifecycle-events.md`
- Prototype: None
- Feature branch exists: `feature/cov-54-emit-lifecycle-events-to-loops`

## Tasks

### Task 1 [Master]: `LoopsEventEmitter` service

**Skills:** write-tests
**Reference:** Read `app/services/loops_contact_synchronizer.rb` (injectable `config:` / `environment:` / `client:` / `client_factory:` seams, gate methods, `ArgumentError` on unknown intent) and `test/services/loops_contact_synchronizer_test.rb` (`build_synchronizer`/`config` helpers, `RecordingClient`, WebMock exact-body assertions).

**In scope:**

- New `app/services/loops_event_emitter.rb`:
  - `initialize(config: Rails.application.config_for(:loops), environment: Rails.env, client: nil, client_factory: -> { LoopsClient.client })` — same signature as `LoopsContactSynchronizer`.
  - Public `emit(user, event_name)`.
  - Returns early (`nil`) unless `production? && config.contact_sync_enabled == true` — reuse COV-51's single switch, **do not** add an `events_enabled` config key.
  - Returns early (`nil`) unless consent holds: `user.marketing_subscribed?` and `user.marketing_opt_in_source != "loops"` (same predicate as `current_app_opt_in?`).
  - `EVENT_PROPERTIES = {"user_signed_up" => ->(user) { {signed_up_at: user.created_at.iso8601} }}.freeze`; `raise ArgumentError, "unknown loops event: #{event_name}"` for anything else (mirrors the synchronizer's unknown-intent branch).
  - Calls `client.send_event(event_name:, user_id: user.id.to_s, event_properties:, idempotency_key:)` — **and nothing else**. No `email:`, no `contact_properties:`, no `mailing_lists:`.
  - `idempotency_key` = `Digest::SHA256.hexdigest("#{event_name}:#{user.id}")`.
  - `# AIDEV-NOTE:` explaining why the gate and consent check are re-asserted here even though the only caller already guarantees both (a gate that holds only via its caller is one refactor from not holding), and why no contact fields are ever passed.

**NOT in scope:**

- Any event other than `user_signed_up`.
- Any change to `LoopsClient`, `LoopsContactSynchronizer`, or `config/loops.yml`.
- Enqueuing or job wiring (Tasks 2–3).

**Build order:**

1. **Test:** new `test/services/loops_event_emitter_test.rb`, copying the private `build_emitter` / `config(enabled:)` helper shape from `loops_contact_synchronizer_test.rb` (config via `ActiveSupport::OrderedOptions`, environment via `ActiveSupport::StringInquirer`). Assert:
   - Each of `development`, `test`, `staging` and `contact_sync_enabled: false` return before constructing a client (`client_factory: -> { flunk "client must not be constructed" }`).
   - A user with `marketing_opt_in_source == "loops"`, and `users(:marketing_unsubscribed)`, emit nothing.
   - **Exact request body** for `users(:marketing_subscribed)` — `stub_request(:post, "https://app.loops.so/api/v1/events/send").with(body: {userId: user.id.to_s, eventName: "user_signed_up", eventProperties: {signed_up_at: user.created_at.iso8601}}.to_json)`, `assert_requested … times: 1`. This is the AC "no top-level contact fields beyond `userId`".
   - The `Idempotency-Key` header equals `Digest::SHA256.hexdigest("user_signed_up:#{user.id}")`.
   - A `409` reply is absorbed: emitter returns `true`, no raise.
   - A `500` reply raises `LoopsClient::InternalError` (so `LoopsRetryable` can catch it).
   - An unknown event name raises `ArgumentError` without any HTTP request.
2. **Implement:** `app/services/loops_event_emitter.rb`.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH"` then `bin/rails test test/services/loops_event_emitter_test.rb`

### Task 2 [Clone]: `LoopsEventJob`

**Skills:** write-tests
**Reference:** Read `app/jobs/loops_contact_sync_job.rb` and `app/jobs/concerns/loops_retryable.rb`. Read `test/jobs/loops_contact_backfill_job_test.rb` for the `ActiveJob::TestHelper` + recording-collaborator style.

**In scope:**

- New `app/jobs/loops_event_job.rb`:
  ```ruby
  class LoopsEventJob < ApplicationJob
    include LoopsRetryable

    def perform(user_id, event_name)
      user = User.find_by(id: user_id)
      return unless user

      LoopsEventEmitter.new.emit(user, event_name)
    end
  end
  ```
  Structure it to mirror `LoopsContactSyncJob` exactly — including the `find_by` / `return unless user` guard for a user deleted between enqueue and perform.

**NOT in scope:**

- Changing `LoopsRetryable`.
- Any enqueue site (Task 3).
- Dead-letter / alerting on exhausted retries — explicitly deferred in the design.

**Build order:**

1. **Test:** new `test/jobs/loops_event_job_test.rb`. Assert:
   - Performing with a valid id calls the emitter with that user and event name (stub `LoopsEventEmitter` construction the way the backfill job test stubs its collaborators, or assert via a WebMock stub with the emitter's config forced on).
   - Performing with a deleted/unknown `user_id` is a no-op and constructs no client.
   - `LoopsEventJob` retries on `LoopsClient::InternalError` — assert this via re-enqueue behavior (`perform_enqueued_jobs` / `assert_enqueued_jobs`), matching however `test/jobs/` already covers retry behavior. If no existing retry assertion pattern exists in this repo, assert module inclusion and note it.
2. **Implement:** `app/jobs/loops_event_job.rb`.
3. **Verify:** `bin/rails test test/jobs/loops_event_job_test.rb`

**Checkpoint 1 ends here.** After this task's work is finished, run review-changes-mini covering Tasks 1–2. If Tasks 1–2 were executed as a parallel batch, the master runs this review once the whole batch returns rather than this task running it itself. Either way it runs exactly once, after both tasks are done.

### Task 3 [Master]: Chain the event off a successful contact sync

**Skills:** write-tests
**Reference:** `app/jobs/loops_contact_sync_job.rb`, `app/models/user/marketing_consent.rb:75` (`capture_registration_marketing_consent` — the sole writer of `"registration"`).

**In scope:**

- Edit `app/jobs/loops_contact_sync_job.rb` so that, **after** `LoopsContactSynchronizer#sync` returns without raising, it enqueues `LoopsEventJob.perform_later(user.id, "user_signed_up")` when **both**:
  - `intent.to_sym == :opt_in`, and
  - `user.marketing_opt_in_source == "registration"`.
- `# AIDEV-NOTE:` recording two things: (a) the enqueue is placed *after* `sync` returns so a failed upsert (which raises and is retried by `LoopsRetryable`) never produces an event against a contact that does not exist; (b) `sync` also returns `nil` for its own gated/no-op paths, and that is deliberately not distinguished here — `LoopsEventEmitter` independently re-checks the same environment gate and consent predicate, so an enqueue on a no-op sync ends in a no-op emit rather than a wrong send.

**NOT in scope:**

- Changing `LoopsContactSynchronizer` or its return contract.
- Any new callback in `User::MarketingConsent` — the model callback stays exactly as it is.
- Emitting inline instead of via a job.

**Build order:**

1. **Test:** new `test/jobs/loops_contact_sync_job_test.rb` (none exists today). With `include ActiveJob::TestHelper` and `setup { clear_enqueued_jobs }`, assert:
   - `opt_in` + `marketing_opt_in_source == "registration"` → exactly one `LoopsEventJob` enqueued with args `[user.id, "user_signed_up"]`.
   - `opt_in` + source `"settings"` → `assert_no_enqueued_jobs only: LoopsEventJob`. **This is the case the ticket exists for.**
   - `opt_out` and `email_change` intents → no `LoopsEventJob`.
   - When the synchronizer raises (stub it to raise `LoopsClient::InternalError`), the error propagates and no `LoopsEventJob` is enqueued.
   - An unknown `user_id` → no sync, no event.
2. **Implement:** the edit to `app/jobs/loops_contact_sync_job.rb`.
3. **Verify:** `bin/rails test test/jobs/loops_contact_sync_job_test.rb test/jobs/loops_event_job_test.rb`

### Task 4 [Clone]: End-to-end lifecycle coverage and AC verification

**Skills:** write-tests
**Reference:** `test/integration/loops_contact_lifecycle_test.rb` — extend it; do not create a parallel file. Use its existing `build_user(marketing_opt_in:)` helper and `assert_enqueued_with` style.

**In scope:**

- Add tests to `test/integration/loops_contact_lifecycle_test.rb` covering the three flows in the design's "Screens / Flows":
  - **Consenting registration:** save a user with `marketing_opt_in: "1"`, then `perform_enqueued_jobs(only: LoopsContactSyncJob)` and assert a `LoopsEventJob` with args `[user.id, "user_signed_up"]` was enqueued as a result.
  - **Non-consenting registration:** `marketing_opt_in: "0"` → `assert_no_enqueued_jobs only: [LoopsContactSyncJob, LoopsEventJob]`.
  - **Settings opt-in by an existing user:** `users(:one).grant_marketing_consent(source: "settings")`, perform the sync job, assert no `LoopsEventJob`.
  - **Registration survives a Loops 500:** with `stub_request(:post, "https://app.loops.so/api/v1/events/send").to_return(status: 500)`, saving a consenting user does not raise — emission is two `perform_later` hops off the request path.
- Then run the full suite and RuboCop, and walk the design's Acceptance Criteria list, confirming each one maps to a named test.

**NOT in scope:**

- Any production-code change. If a test here fails, report it rather than fixing production code — that means Tasks 1–3 have a gap.
- Rewriting or reorganizing the existing tests in that file.

**Build order:**

1. **Test:** the four cases above appended to `test/integration/loops_contact_lifecycle_test.rb`.
2. **Implement:** none — test-only task.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH"` then `bin/rails test` (full suite, show output) and `bin/rubocop` (project-wide, not on individual paths), then `git diff` and report.

**Checkpoint 2 ends here.** After this task's work is finished, run review-changes-mini covering Tasks 3–4. If Tasks 3–4 were executed as a parallel batch, the master runs this review once the whole batch returns rather than this task running it itself. Either way it runs exactly once, after both tasks are done.

## Task Dependencies

- Task 2 depends on Task 1 (the job calls `LoopsEventEmitter`).
- Task 3 depends on Task 2 (the sync job enqueues `LoopsEventJob`).
- Task 4 depends on Task 3 (asserts the full chain).
- **No tasks can run in parallel** — this is a four-link chain, each task ~2 files.

## Decisions made where the design left room

Both are recorded in Task 3's AIDEV-NOTE:

1. **"Successful sync" means "did not raise", not "wrote something."**
   `LoopsContactSynchronizer#sync` returns `nil` both when it is gated off and
   when consent does not hold, and returns the parsed response body otherwise —
   so its return value cannot cleanly distinguish success from no-op without
   changing COV-51's contract. It does not need to: every no-op reason is
   independently re-checked by `LoopsEventEmitter`, so an enqueue after a no-op
   sync ends in a no-op emit. This keeps the change to the three files the
   design named. Visible consequence: in test/dev a `LoopsEventJob` *is*
   enqueued and then no-ops.
2. **No new config key.** Events ride COV-51's `contact_sync_enabled`, which is
   what keeps staging from writing into the production audience.
