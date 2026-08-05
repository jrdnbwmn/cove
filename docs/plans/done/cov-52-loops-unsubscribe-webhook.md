> Ticket: COV-52
> Branch: feature/cov-52-unsubscribe-and-suppression-reconciliation

# Plan: Loops unsubscribe and suppression webhook

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | `loops_webhook_events` table + model | Master | ✅ |
| 2 | 1 | 1 | HMAC-SHA256 signature verifier | Master | ✅ |
| 3 | 1 | 1 | Opt-out severity + `record_loops_opt_out` + narrowed grant | Master | ✅ |
| 4 | 2 | 2 | Event processor (mapping, identity, ordering guards) | Master | ✅ |
| 5 | 2 | 2 | `LoopsWebhookEventJob` | Master | ✅ |
| 6 | 2 | 2 | `POST /webhooks/loops` controller + route | Master | ✅ |
| 7 | 3 | 3 | 30-day pruning job + `config/recurring.yml` | Clone | ✅ |
| 8 | 3 | 3 | End-to-end + regression tests | Clone | ✅ |
| 9 | 3 | 3 | Production credential + dashboard registration (manual) | Master | ✅ |

## Prerequisites

- Design: `docs/designs/cov-52-loops-unsubscribe-webhook.md`
- Prototype: None (no UI changes)
- Feature branch exists: `feature/cov-52-unsubscribe-and-suppression-reconciliation`

## Assumptions

Approved by the user at planning time; the design doesn't state these.

1. **`record_loops_opt_out` records even for a never-subscribed user.**
   `withdraw_marketing_consent` returns early unless `marketing_subscribed?`. A
   hard bounce or spam report for someone who never opted in is still a fact
   about that address worth recording, so the new method does *not* take that
   early return.
2. **`eventTime` unit.** Loops documents it only as "Unix timestamp". Task 1
   parses defensively — values above `100_000_000_000` are treated as
   milliseconds — with an `AIDEV-NOTE`.
3. **Test secret via stub, not test credentials.** `config/credentials/test.key`
   is gitignored, so baking `loops.webhook_secret` into `test.yml.enc` would be
   undecryptable on any other machine or in CI. Tests stub
   `LoopsWebhookSignature.secret` instead.

## Tasks

### Task 1 [Master]: `loops_webhook_events` table and model

**Skills:** safe-migration, write-tests
**Reference:** `db/migrate/20260803200832_add_marketing_consent_to_users.rb`, `lib/jumpstart/app/models/inbound_webhook.rb`, `test/fixtures/users.yml`

**In scope:**

- Migration `create_loops_webhook_events`: `webhook_id` (string, `null: false`,
  unique index), `event_name` (string, `null: false`), `event_time` (datetime),
  `payload` (jsonb, `null: false`, `default: {}`), `processed_at` (datetime),
  timestamps. No FK to users.
- `app/models/loops_webhook_event.rb`: `RETENTION = 30.days`;
  `scope :prunable, -> { where(created_at: ...RETENTION.ago) }`;
  `scope :unprocessed, -> { where(processed_at: nil) }`; `#processed!` setting
  `processed_at` to `Time.current`; `.parse_event_time(value)` returning a
  `Time` or nil (seconds vs. milliseconds heuristic).
- `AIDEV-NOTE` on the class: 30-day retention must outlive Loops' 24-hour retry
  window, because `Webhook-Id` dedupe is the only replay defence.
- `AIDEV-NOTE` on `parse_event_time`: Loops documents only "Unix timestamp";
  the ms threshold is a defensive guess.
- `test/fixtures/loops_webhook_events.yml`: `one` (processed
  `contact.unsubscribed`), `unprocessed` (`email.hardBounced`, `processed_at`
  nil), `stale` (`created_at: <%= 31.days.ago %>`).

**NOT in scope:**

- Any association to `User`; any processing logic; the pruning job (Task 7).

**Build order:**

1. **Test:** `test/models/loops_webhook_event_test.rb` — a duplicate
   `webhook_id` raises `ActiveRecord::RecordNotUnique`; `prunable` returns only
   `stale`; `unprocessed` returns only `unprocessed`; `processed!` stamps
   `processed_at`; `parse_event_time` handles seconds, milliseconds, and nil.
2. **Implement:** migration + model + fixtures.
3. **Verify:** `bin/rails db:migrate && bin/rails test test/models/loops_webhook_event_test.rb`,
   then `git diff db/*schema.rb` and `git checkout --` the three non-primary
   schema dumps if they only show reordering (see AGENTS.md gotcha).

---

### Task 2 [Master]: HMAC-SHA256 signature verifier

**Skills:** write-tests
**Reference:** `app/services/loops_contact_synchronizer.rb` (service shape, injectable config)

**In scope:**

- `app/services/loops_webhook_signature.rb`:
  - `.secret` → `Rails.application.credentials.dig(:loops, :webhook_secret)`.
  - `.new(secret: secret)` and
    `#valid?(webhook_id:, timestamp:, payload:, signature_header:)`.
  - Algorithm: `secret.split("_")[1]` → `Base64.decode64` →
    `OpenSSL::HMAC.digest("SHA256", key, "#{webhook_id}.#{timestamp}.#{payload}")`
    → `Base64.strict_encode64`.
  - Header is space-separated entries of the form `v1,<signature>`; valid if
    **any** entry's signature matches. Compare with
    `ActiveSupport::SecurityUtils.secure_compare`.
  - Fails closed (returns `false`, never raises) on blank secret, secret with no
    `_`, blank/malformed header, or blank `webhook_id`/`timestamp`.
- `AIDEV-NOTE`: the secret is prefix-stripped *then* base64-decoded — COV-48's
  brief said only "base64-decoded", and getting this wrong makes every event
  fail silently.

**NOT in scope:**

- Timestamp-tolerance/replay-window checks (explicitly rejected by the design).
- Reading the secret anywhere other than credentials; no `config/loops.yml` entry.

**Build order:**

1. **Test:** `test/services/loops_webhook_signature_test.rb` — a signature
   computed by the test itself over `"#{id}.#{ts}.#{body}"` validates; a `v1,`
   header among several entries validates; wrong signature, tampered body,
   tampered id, tampered timestamp, missing header, malformed header, `nil`
   secret, and secret without `_` all return false.
2. **Implement:** the service.
3. **Verify:** `bin/rails test test/services/loops_webhook_signature_test.rb`

---

### Task 3 [Master]: Opt-out severity, `record_loops_opt_out`, narrowed grant

**Skills:** write-tests
**Reference:** `app/models/user/marketing_consent.rb`, `test/models/user/marketing_consent_test.rb`

**In scope:**

- In `app/models/user/marketing_consent.rb`:
  - `LOOPS_OPT_OUT_SEVERITY = {"user_app" => 0, "user_loops" => 1, "mailing_list_unsubscribe" => 2, "hard_bounce" => 3, "spam_report" => 4}.freeze`
  - `record_loops_opt_out(reason:, occurred_at:)` — returns `self` unchanged when
    the current reason's severity is **≥** the new one; otherwise sets
    `marketing_opt_out_reason` to the new reason and `marketing_opt_out_at` to
    the **earliest** of the existing value and `occurred_at`; saves. Applies
    regardless of `marketing_subscribed?` (see Assumption 1).
  - Narrow the grant: `grant_marketing_consent(source:)` refuses when the reason
    is `hard_bounce`/`spam_report` for any source, and when it is
    `user_loops`/`mailing_list_unsubscribe` for any source **except** `"loops"`.
    Implement as a private `marketing_opt_out_protected_against?(source)`; leave
    the public `marketing_opt_out_protected?` and
    `PROTECTED_MARKETING_OPT_OUT_REASONS` untouched —
    `app/views/devise/registrations/edit.html.erb:73` uses them to disable the
    toggle and pick COV-49's copy, and that behaviour must not change.
  - `AIDEV-NOTE` on the narrowing: the in-app toggle still refuses for all five
    reasons (COV-49's copy stays true); only a Loops-originated resubscribe may
    clear `user_loops`/`mailing_list_unsubscribe`.

**NOT in scope:**

- New columns; changes to `enqueue_contact_sync`; changes to the settings view
  or its i18n.

**Build order:**

1. **Test:** in `test/models/user/marketing_consent_test.rb` — severity escalates
   (`user_loops` → `hard_bounce` overwrites); does not de-escalate
   (`spam_report` → `user_loops` no-ops); `marketing_opt_out_at` keeps the
   earliest of the two timestamps; equal severity no-ops; a never-subscribed
   user records the opt-out; `grant_marketing_consent(source: "loops")` clears
   `user_loops` and `mailing_list_unsubscribe` but is refused for
   `hard_bounce`/`spam_report`; `grant_marketing_consent(source: "settings")` is
   refused for all four; `marketing_opt_out_protected?` still returns true for
   all four.
2. **Implement:** the concern changes.
3. **Verify:** `bin/rails test test/models/user/marketing_consent_test.rb test/integration/marketing_preferences_ui_test.rb test/controllers/marketing_preferences_controller_test.rb`
4. **Checkpoint 1 review:** this is the last task of checkpoint 1 (Tasks 1–3) —
   run review-changes-mini over Tasks 1–3 once the work is finished. If
   checkpoint 1 was executed as a parallel batch, the master runs this once the
   whole batch returns.

---

### Task 4 [Master]: `LoopsWebhookEventProcessor`

**Skills:** write-tests
**Reference:** `app/services/loops_contact_synchronizer.rb` (injectable `config:`), `config/loops.yml`

**In scope:**

- `app/services/loops_webhook_event_processor.rb`,
  `.new(config: Rails.application.config_for(:loops))`, `#call(event)`:
  - **Identity:** `payload.dig("contactIdentity", "userId")` →
    `User.find_by(id: ...)`; fall back to
    `payload.dig("contactIdentity", "email")` → `User.find_by(email: ...)`. No
    match → `Rails.logger.info` naming the event name and `webhook_id`, return
    without error.
  - **Mapping:** `contact.unsubscribed` / `email.unsubscribed` →
    `record_loops_opt_out(reason: "user_loops")`; `email.spamReported` →
    `"spam_report"`; `email.hardBounced` → `"hard_bounce"`;
    `contact.mailingList.unsubscribed` → `"mailing_list_unsubscribe"` **only if**
    `payload.dig("mailingList", "id") == config.contact_sync_mailing_list_id`,
    otherwise no state change; `email.resubscribed` →
    `grant_marketing_consent(source: "loops")` (ignore a `false` return — a
    protected reason legitimately refuses). Any other event name → no-op, no
    raise.
  - **Ordering guards**, using `event.event_time` (skip the guard entirely when
    `event_time` is nil): an opt-out is skipped when
    `user.marketing_opt_in_at.present? && user.marketing_opt_in_at > event_time`;
    a resubscribe is skipped when
    `user.marketing_opt_out_at.present? && user.marketing_opt_out_at > event_time`.
  - `user.reload` before writing, matching COV-51's defensive shape.
- `AIDEV-NOTE` on the mailing-list branch: only the Cove updates list changes
  state; other lists are recorded and ignored, and this should not need
  revisiting when a second list exists.

**NOT in scope:**

- Setting `processed_at` (Task 5); any outbound Loops API call; anything for
  `contact.deleted`, `email.softBounced`, opens, clicks, or deliveries beyond
  the catch-all no-op.

**Build order:**

1. **Test:** `test/services/loops_webhook_event_processor_test.rb` — one test per
   row of the mapping table; mailing-list unsubscribe for a non-Cove list changes
   nothing; unknown `userId` **and** unknown email is a silent no-op; email
   fallback resolves a user when `userId` is null; `testing.testEvent` and
   `email.opened` are no-ops; stale opt-out (`event_time` before
   `marketing_opt_in_at`) is ignored; stale resubscribe is ignored;
   `email.resubscribed` for a `spam_report` user leaves state alone.
2. **Implement:** the service.
3. **Verify:** `bin/rails test test/services/loops_webhook_event_processor_test.rb`

---

### Task 5 [Master]: `LoopsWebhookEventJob`

**Skills:** write-tests
**Reference:** `app/jobs/loops_contact_sync_job.rb`

**In scope:**

- `app/jobs/loops_webhook_event_job.rb`: `perform(event_id)` →
  `LoopsWebhookEvent.find_by(id: event_id)`, return unless present, return if
  already `processed_at`, run `LoopsWebhookEventProcessor.new.call(event)`, then
  `event.processed!`.
- Do **not** include `LoopsRetryable` — there are no HTTP calls; standard
  ActiveJob retry semantics apply and `processed_at` stays nil on failure,
  leaving the row retryable.

**NOT in scope:**

- Custom `retry_on`; a dead-letter or alerting path; the controller (Task 6).

**Build order:**

1. **Test:** `test/jobs/loops_webhook_event_job_test.rb` — processing an
   unprocessed event applies the state change and stamps `processed_at`; an
   already-processed event is skipped (processor not called); a missing id is a
   no-op; a processor exception leaves `processed_at` nil and re-raises.
2. **Implement:** the job.
3. **Verify:** `bin/rails test test/jobs/loops_webhook_event_job_test.rb`

---

### Task 6 [Master]: `POST /webhooks/loops` controller and route

**Skills:** write-tests
**Reference:** `lib/jumpstart/app/controllers/inbound_webhooks/application_controller.rb` (base class + `payload` helper), `lib/jumpstart/lib/generators/inbound_webhook/templates/controller.rb.tt`, `config/routes.rb`

**In scope:**

- `config/routes/webhooks.rb`:
  `post "webhooks/loops", to: "inbound_webhooks/loops#create"`; add
  `draw :webhooks` to `config/routes.rb` (the design specifies routes.rb, not
  the jumpstart file).
- `app/controllers/inbound_webhooks/loops_controller.rb` inheriting
  `InboundWebhooks::ApplicationController` (`ActionController::API` — CSRF and
  authentication are absent by construction, no `skip_before_action` needed):
  1. Verify `Webhook-Signature` over `Webhook-Id`, `Webhook-Timestamp`, and
     `request.raw_post`. Fail → `head :unauthorized` (401), nothing recorded.
  2. `JSON.parse` the body; `JSON::ParserError` → `head :bad_request` (400).
  3. `LoopsWebhookEvent.create!(webhook_id:, event_name: parsed["eventName"],
     event_time: LoopsWebhookEvent.parse_event_time(parsed["eventTime"]),
     payload: parsed)`; rescue `ActiveRecord::RecordNotUnique` → `head :ok`, no
     job enqueued.
  4. `LoopsWebhookEventJob.perform_later(record.id)`, then `head :ok`.

**NOT in scope:**

- Any processing inline in the request; a GET/health route; an admin UI for the
  event log.

**Build order:**

1. **Test:** `test/controllers/inbound_webhooks/loops_controller_test.rb`,
   signing bodies with a stubbed `LoopsWebhookSignature.secret` — a validly
   signed request returns 200, creates one row, and enqueues one
   `LoopsWebhookEventJob`; missing / malformed / wrong signature returns 401 and
   creates nothing; malformed JSON with a valid signature returns 400; a
   redelivered `Webhook-Id` returns 200, creates no second row, and enqueues
   nothing; with the secret unset every request is 401.
2. **Implement:** route file, `draw :webhooks`, controller.
3. **Verify:** `bin/rails test test/controllers/inbound_webhooks/loops_controller_test.rb`
4. **Checkpoint 2 review:** last task of checkpoint 2 (Tasks 4–6) — run
   review-changes-mini over Tasks 4–6. If the checkpoint ran as a parallel
   batch, the master runs it once the batch returns.

---

### Task 7 [Clone]: 30-day pruning job

**Skills:** write-tests
**Reference:** `app/jobs/loops_contact_sync_job.rb`, `config/recurring.yml` (currently all commented-out examples)

**In scope:**

- `app/jobs/loops_webhook_event_pruning_job.rb`:
  `LoopsWebhookEvent.prunable.delete_all`.
- `config/recurring.yml`: a real `production:` entry running the job daily. Leave
  the commented examples in place.

**NOT in scope:**

- Pruning in any other environment; archiving before delete; touching the
  queue/cable/cache schemas.

**Build order:**

1. **Test:** `test/jobs/loops_webhook_event_pruning_job_test.rb` — deletes the
   `stale` fixture, keeps events inside the window, and is safe on an empty
   table.
2. **Implement:** job + `config/recurring.yml`.
3. **Verify:** `bin/rails test test/jobs/loops_webhook_event_pruning_job_test.rb`

---

### Task 8 [Clone]: End-to-end and regression tests

**Skills:** write-tests
**Reference:** `test/integration/loops_contact_lifecycle_test.rb` (`assert_no_enqueued_jobs only:` patterns), `test/services/loops_contact_synchronizer_test.rb`

**In scope:**

- `test/integration/loops_webhook_test.rb`, posting real signed bodies and
  running jobs inline:
  - **The central regression guard:** for every one of the six handled events,
    `assert_no_enqueued_jobs only: LoopsContactSyncJob` around the full
    receive-and-process cycle. Nothing a webhook does may echo back to Loops.
  - Full path per event: signed POST → 200 → job runs → user's consent columns
    hold the expected reason/source → `processed_at` set.
  - A hard bounce followed by a `contact.unsubscribed` (both orders) settles on
    `hard_bounce` with the earliest `marketing_opt_out_at`.
  - An event for an unknown `userId` and unknown email is recorded, marked
    processed, and raises nothing.
- Two tests naming the design's "already true" criteria:
  `LoopsContactSynchronizer#sync(user, intent: :opt_in)` makes no call for a user
  whose `marketing_opt_in_source` is `"loops"` (add to
  `test/services/loops_contact_synchronizer_test.rb` if not already covered); and
  the settings toggle renders disabled with the right copy for a `user_loops`
  opt-out (add to `test/integration/marketing_preferences_ui_test.rb` if not
  already covered). Check first — do not duplicate an existing assertion.

**NOT in scope:**

- System tests; any new production code — if a test fails, report it rather than
  changing app code.

**Build order:**

1. **Test:** write the tests above.
2. **Implement:** nothing.
3. **Verify:** `bin/rails test test/integration/loops_webhook_test.rb test/services/loops_contact_synchronizer_test.rb test/integration/marketing_preferences_ui_test.rb`

---

### Task 9 [Master]: Production credential and dashboard registration

**In scope:**

- Add `loops.webhook_secret` to `config/credentials/production.yml.enc` under the
  existing `loops:` key, using the `whsec_<base64>` value from the Loops
  dashboard.
- Register the endpoint in Loops: Settings → Webhooks →
  `https://covehomeschool.com/webhooks/loops`.
- **This needs the user.** The secret is shown once at creation and there's one
  webhook endpoint per Loops account. Prompt for it rather than guessing — and
  tell the user it's a value worth saving in their own records. Fire
  `testing.testEvent` from the dashboard afterwards to confirm wiring.

**NOT in scope:**

- Staging or development secrets — their absence is the intended fail-closed
  guard.

**Build order:**

1. **Verify:** `bin/rails test` (full suite) and `bin/rubocop`, then `git diff`
   for review.
2. **Checkpoint 3 review:** last task of checkpoint 3 (Tasks 7–9) — run
   review-changes-mini over Tasks 7–9. If the checkpoint ran as a parallel
   batch, the master runs it once the batch returns.

## Task Dependencies

- Task 1 → Tasks 4, 5, 6, 7 (all need the model)
- Task 2 → Task 6 (controller verifies signatures)
- Task 3 → Task 4 (processor calls `record_loops_opt_out`)
- Task 4 → Task 5 → Task 6 (each wraps the previous)
- Task 6 → Task 8 (end-to-end tests need the endpoint)
- Tasks 1, 2, 3 can run in parallel — no shared files.
- Tasks 4, 5, 6 are strictly sequential.
- Tasks 7 and 8 can run in parallel with each other; Task 9 is manual and can
  happen any time after Task 6.
