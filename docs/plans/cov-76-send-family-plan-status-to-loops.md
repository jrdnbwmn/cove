> Ticket: COV-76
> Branch: feature/cov-76-send-family-plan-status-to-loops

# Plan: Send Family Plan Status to Loops

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add and test the plan-status contact payload | Master | ✅ |
| 2 | 1 | 1 | Add subscription and complimentary-status triggers | Master | ✅ |
| 3 | 1 | 1 | Add family-membership triggers | subagent | ✅ |
| 4 | 1 | 2 | Record the project decision in generated agent guidance | Master | ✅ |

## Prerequisites

- Design: [`docs/designs/cov-76-send-family-plan-status-to-loops.md`](../designs/cov-76-send-family-plan-status-to-loops.md)
- Prototype: None — backend only
- Feature branch exists: `feature/cov-76-send-family-plan-status-to-loops`
- Branch currently matches `origin/main`; the design document is the only untracked file.
- Use Ruby 4.0.5 by prepending `/Users/jordan/.local/share/mise/shims` to `PATH` for Rails commands.
- The Loops `planStatus` string property already exists. Do not mutate Loops or perform live verification; COV-78 owns the production check.
- Before Task 4, locate the Claude-side source that generates `AGENTS.md`. Do not edit generated `AGENTS.md` directly.

## Tasks

### Task 1 [Master]: Add the plan-status contact payload

**Skills:** loops-api, write-tests
**Reference:** Read [`app/services/loops_contact_synchronizer.rb`](../../app/services/loops_contact_synchronizer.rb), [`test/services/loops_contact_synchronizer_test.rb`](../../test/services/loops_contact_synchronizer_test.rb), [`app/jobs/loops_contact_sync_job.rb`](../../app/jobs/loops_contact_sync_job.rb), and [`test/jobs/loops_contact_sync_job_test.rb`](../../test/jobs/loops_contact_sync_job_test.rb).

**In scope:**

- Add `planStatus` to the existing `:opt_in` payload, derived live from `user.family.plan_status`.
- Add the `:plan_status` intent with exactly `email`, `userId`, and `planStatus`.
- Require current `marketing_subscribed?` consent for `:plan_status`, including Loops-sourced consent.
- Return without a request when the user is opted out or has no current family.
- Preserve the production and `contact_sync_enabled` gates.
- Prove the intent does not require a mailing-list ID and does not send `subscribed` or `mailingLists`.
- Prove `LoopsContactSyncJob` forwards the intent, ignores a missing user, and retains `LoopsRetryable` behavior.

**NOT in scope:**

- A new job, service, client method, configuration field, or stored plan value.
- Changing opt-out, email-change, deletion, backfill, or signup-event behavior.
- Modifying mailing-list membership through the new intent.
- Creating or updating the external Loops property.

**Build order:**

1. **Test:** Extend the two existing test files with exact-payload assertions for `:opt_in` and `:plan_status`; cover Loops-sourced consent, opt-out, missing family, runtime gates, missing mailing-list configuration, job forwarding, missing users, and retryable failures.
2. **Implement:** Update `LoopsContactSynchronizer#sync` and `subscribed_attributes`. Resolve the family and its status when the job runs so retries and out-of-order jobs converge on current state. No production change to `LoopsContactSyncJob` is expected unless the failing tests expose an actual intent-handling restriction.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/services/loops_contact_synchronizer_test.rb test/jobs/loops_contact_sync_job_test.rb`

### Task 2 [Master]: Add family-wide subscription and complimentary-status triggers

**Skills:** loops-api, write-tests
**Reference:** Read [`config/initializers/pay.rb`](../../config/initializers/pay.rb), [`app/models/account.rb`](../../app/models/account.rb), [`test/integration/subscriptions_test.rb`](../../test/integration/subscriptions_test.rb), and the paid/complimentary fixture states in [`test/fixtures/accounts.yml`](../../test/fixtures/accounts.yml) and [`test/fixtures/pay/subscriptions.yml`](../../test/fixtures/pay/subscriptions.yml).

**In scope:**

- Create `test/integration/loops_plan_status_sync_test.rb`.
- Add an `Account` helper that queues `LoopsContactSyncJob.perform_later(user.id, "plan_status")` for `parents.marketing_subscribed`.
- Add an `Account` `after_update_commit` guarded only by `saved_change_to_complimentary_premium?`.
- Add Pay subscription `after_commit` callbacks for create and for updates changing `status` or `ends_at`.
- Resolve the family from `Pay::Subscription#customer.owner`.
- Test active subscription creation as `premium` and an ended cancellation as `free`.
- Test comp-on as `complimentary`, comp-off as `free`, and comp-off with a paid subscription as `premium`.
- Prove every opted-in parent is queued and a non-opted-in parent is skipped.
- Reuse the existing fixture labels and create only test-local membership/state transitions; do not add broadly subscribed fixtures that would break the existing singleton consent-scope assertions.

**NOT in scope:**

- Subscription quantity changes, billing-email behavior, checkout behavior, or Pay webhook changes.
- Sending a job for unrelated subscription or account updates.
- Treating `past_due` as anything other than `premium`.
- Preloading `billable_subscriptions` or caching `plan_status`.
- Contacting Loops outside the test recording client.

**Build order:**

1. **Test:** Create the integration test using the existing `marketing_subscribed`, `subscribed`, `complimentary`, and Pay fixtures. Exercise callbacks and perform the resulting job through a real synchronizer configured as production with a recording client; assert exact status values, user IDs, and consent filtering.
2. **Implement:** Add the reusable public family fan-out method and guarded account callback in `app/models/account.rb`. Add the create/update callbacks and small delegating method inside the existing `pay_subscription` block in `config/initializers/pay.rb`.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/integration/loops_plan_status_sync_test.rb`

### Task 3 [subagent]: Add family-membership triggers

**Skills:** loops-api, write-tests
**Reference:** Read [`app/models/account_user.rb`](../../app/models/account_user.rb), [`app/services/family_invitation_acceptance.rb`](../../app/services/family_invitation_acceptance.rb), [`app/controllers/account_users_controller.rb`](../../app/controllers/account_users_controller.rb), and their existing service/integration tests.

**In scope:**

- Add an `AccountUser` `after_commit` callback for create and destroy.
- Queue only the moving user’s `plan_status` job, and only when that user is currently marketing-subscribed.
- Extend `test/integration/loops_plan_status_sync_test.rb` with realistic invitation-acceptance and parent-removal transitions.
- Prove both callbacks in a family move read the final family and converge on its current status.
- Prove the parent who remains in the old family receives no membership-triggered job.
- Prove a non-opted-in moving user queues nothing.
- Preserve the synchronizer’s second consent check for changes between enqueue and execution.

**NOT in scope:**

- Changing invitation acceptance, family-removal transactions, capacity validation, or default-family creation.
- Sending plan-status updates to every parent for a one-user membership move.
- Deduplicating the deliberate destroy/create pair.
- Passing a family ID or plan value into the job.

**Build order:**

1. **Test:** Add membership tests before the callback. Grant consent through existing model behavior, execute an invitation move and owner removal, inspect exact enqueued arguments, then perform jobs and assert they send the final family’s current status.
2. **Implement:** Add the create/destroy `after_commit` and a private enqueue helper to `app/models/account_user.rb`, using the destroyed record’s user identity safely and checking current consent before enqueue.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/integration/loops_plan_status_sync_test.rb`
4. **Checkpoint review:** After Tasks 1–3 are complete, run `review-changes-mini` exactly once for checkpoint 1. If Tasks 2–3 overlap in execution, the master waits until all work returns before running the review.

### Task 4 [Master]: Record the Loops plan-status project decision

**Skills:** engineering:documentation
**Reference:** Read the generated-file warning at the top of [`AGENTS.md`](../../AGENTS.md), its “Current Project Decisions” section, the approved COV-76 design, and [`docs/designs/cov-71-monetization-family-audit.md`](../designs/cov-71-monetization-family-audit.md).

**In scope:**

- Locate the authoritative Claude-side source that generates the repository’s `AGENTS.md`.
- Record that consented Loops contacts carry `planStatus` with `premium`, `complimentary`, or `free`.
- State that plan status is the sole override to COV-51’s no-plan-information rule.
- Regenerate `AGENTS.md` through the established one-way process.
- Keep the archived COV-51 design unchanged.

**NOT in scope:**

- Editing generated `AGENTS.md` directly.
- Rewriting archived design documents.
- Documenting other contact properties or the deferred Loops sequences.
- Continuing with a guessed generator path or manual substitute if the authoritative source cannot be found.

**Build order:**

1. **Test:** Identify the authoritative source and compare its project-decision section with generated `AGENTS.md`.
2. **Implement:** Add the single COV-76 decision to that source and regenerate the repository file. If the source or regeneration process remains unavailable, stop and report the precise blocker.
3. **Verify:** Inspect `git diff -- AGENTS.md` for the intended decision only, then run `git diff --check`.
4. **Checkpoint review:** Run `review-changes-mini` exactly once for checkpoint 2 after the generated documentation is verified.

## Task Dependencies

- Task 1 establishes the payload and job contract used by every trigger.
- Task 2 depends on Task 1 and establishes the shared family-wide fan-out method.
- Task 3 depends on Task 1 but is sequential after Task 2 because both tasks extend `test/integration/loops_plan_status_sync_test.rb`.
- Task 4 can be researched alongside code work, but regeneration waits until the final implementation vocabulary is stable.
- Checkpoint 1 covers Tasks 1–3; checkpoint 2 covers Task 4.
- After checkpoint 2, the master runs `ruby -v`, the focused COV-76 tests, full `bin/rails test`, project-wide `bin/rubocop`, `git diff --check`, `git diff origin/main...`, and `git status --short`.
- Live production verification remains deferred to COV-78.
