> Ticket: COV-51
> Branch: feature/cov-51-sync-users-to-loops-contacts

# Plan: Sync consenting users to Loops contacts

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add production-only configuration and intent-aware synchronization | Master | ✅ |
| 2 | 1 | 1 | Connect user lifecycle and deletion events to retryable jobs | Master | ✅ |
| 3 | 2 | 2 | Add the resumable, throttled contact backfill job | subagent | |
| 4 | 2 | 2 | Add guarded dry-run and enqueue operations | subagent | |
| 5 | 3 | 3 | Run integrated verification and final review | Master | |

## Prerequisites

- Design: [`docs/designs/cov-51-sync-users-to-loops-contacts.md`](../designs/cov-51-sync-users-to-loops-contacts.md)
- Governing architecture: [`docs/designs/cov-48-marketing-architecture.md`](../designs/cov-48-marketing-architecture.md)
- Prototype: None; this feature is entirely background and operational behavior
- Feature branch exists: `feature/cov-51-sync-users-to-loops-contacts`
- Architecture references reviewed: `docs/architecture/app-structure.mermaid`, `docs/architecture/data-model.mermaid`, and `docs/architecture/routes-map.mermaid`
- COV-50's existing `LoopsClient#update_contact`, `#delete_contact`, and injectable throttler are the only Loops API seam; do not add a gem or duplicate HTTP code
- Run Rails and RuboCop commands through mise using `mise exec --`
- The design and approved plan must be annotated and committed together before `/prompts:execute-plan`, which requires a clean worktree

## Tasks

### Task 1 [Master]: Add production-only configuration and intent-aware synchronization

**Skills:** write-tests, loops-api
**Reference:** Read [`app/clients/loops_client.rb`](../../app/clients/loops_client.rb), [`test/clients/loops_client_test.rb`](../../test/clients/loops_client_test.rb), [`config/loops.yml`](../../config/loops.yml), and the payload rules in the COV-51 design

**In scope:**

- Add the verified `Cove updates` list ID `cmsdo8ncl02wc0j0j4rxwhy4l` to `config/loops.yml`.
- Configure `contact_sync_enabled: true` only for production and `false` for development, test, and staging.
- Add `LoopsContactSynchronizer` as the single owner of contact payload construction and runtime guards.
- Return before client construction in every non-production or disabled environment.
- Upsert opt-ins with email, string user ID, `subscribed: true`, and list membership `true`.
- Send app opt-outs by user ID with `subscribed: false` and list membership `false`; omit email.
- Send email changes with current email and user ID while omitting subscription and list fields.
- Delete by string user ID and treat `LoopsClient::NotFound` as successful completion.
- Recheck current consent/source/reason before writes so stale intents cannot reverse newer state.
- Expose one shared backfill-readiness check that reports or raises separately for environment, enabled flag, and mailing-list configuration.

**NOT in scope:**

- Model callbacks, Active Jobs, Rake tasks, migrations, UI, webhooks, suppression changes, contact creation, or storing Loops IDs.
- Sending names, account data, consent timestamps, roles, plans, or custom properties.
- Retrying inside the synchronizer or implementing a new throttling algorithm.

**Build order:**

1. **Test:** Add `test/services/loops_contact_synchronizer_test.rb` first. Prove:
   - Checked-in configuration contains the exact list ID and explicit environment flags.
   - Development, test, staging, and a disabled production configuration return before client construction and HTTP.
   - Missing list configuration fails visibly for opt-in, opt-out, and live-backfill readiness.
   - Current app opt-in produces exactly one `PUT /v1/contacts/update` containing only `email`, string `userId`, `subscribed: true`, and `{list_id: true}`.
   - Current `user_app` opt-out sends only string `userId`, `subscribed: false`, and `{list_id: false}`.
   - Email-change intent sends only current email and string user ID.
   - Stale opt-in, stale opt-out, protected opt-out, and Loops-originated consent intents send nothing.
   - Deletion uses `POST /v1/contacts/delete` with a plain string `userId`, and 404 is accepted.
   - The environment/configuration seam can be tested without globally mutating `Rails.env` in parallel tests.
2. **Implement:** Update `config/loops.yml`; add `app/services/loops_contact_synchronizer.rb` with default Rails configuration/environment/client dependencies, explicit intent handling, configuration errors, and optional client injection for backfill reuse. Construct the default `LoopsClient` only after runtime guards pass.
3. **Verify:** `mise exec -- bin/rails test test/services/loops_contact_synchronizer_test.rb`

### Task 2 [Master]: Connect user lifecycle and deletion events to retryable jobs

**Skills:** write-tests
**Reference:** Read [`app/models/user/marketing_consent.rb`](../../app/models/user/marketing_consent.rb), [`test/models/user/marketing_consent_test.rb`](../../test/models/user/marketing_consent_test.rb), [`app/jobs/loops_mail_delivery_job.rb`](../../app/jobs/loops_mail_delivery_job.rb), and [`test/jobs/loops_mail_delivery_job_test.rb`](../../test/jobs/loops_mail_delivery_job_test.rb)

**In scope:**

- Add after-commit lifecycle hooks without changing the existing public consent API.
- Enqueue `opt_in` after explicitly consenting registration/settings changes.
- Enqueue `opt_out` only for app-originated `user_app` transitions.
- Enqueue `email_change` only when pre-save consent history proves the user previously entered the Loops audience.
- Avoid a redundant email-change job when the same commit's opt-in payload already carries the latest email.
- Enqueue deletion for every destroyed user using only `id.to_s`, never GlobalID or email.
- Add separate lifecycle and deletion jobs that reload current state or use the deletion snapshot.
- Retry Loops rate limits, server failures, open/read timeouts, and connection-level errors with polynomial backoff.
- Let permanent validation, authorization, and identity errors remain visible failures.

**NOT in scope:**

- Name-change synchronization, protected/Loops-originated consent echoing, inline HTTP, swallowing permanent failures, a shared progress table, or changing controllers/forms.
- Performing jobs inside the originating database transaction.
- Retrying missing users or creating a local "was synced" marker.

**Build order:**

1. **Test:** Add `test/integration/loops_contact_lifecycle_test.rb` first. Cover:
   - Unchecked creation enqueues no contact job and issues no HTTP.
   - Checked creation commits successfully and enqueues `[user.id, "opt_in"]`.
   - Settings opt-in and `user_app` opt-out enqueue their exact intents after commit.
   - Loops/protected provenance changes, no-op consent saves, and name changes enqueue nothing.
   - A previously consenting user's email change enqueues `email_change`; a never-consenting user's does not.
   - Hard-bounce email reset still enqueues email maintenance based on the pre-save state.
   - Simultaneous opt-in/email change does not enqueue redundant work.
   - Destroy enqueues deletion with one plain string ID even if the user never consented.
   - Lifecycle jobs reload by ID, exit for deleted users, and delegate current state rather than captured email/consent values.
   - Deletion jobs delegate the snapshotted ID and accept an already-missing Loops contact.
   - Both job classes declare the required transient retry handlers while leaving permanent errors unhandled.
2. **Implement:** Update `app/models/user/marketing_consent.rb`; add `app/jobs/loops_contact_sync_job.rb` and `app/jobs/loops_contact_deletion_job.rb`. Keep callback methods private and limited to intent selection plus `perform_later`.
3. **Verify:** `mise exec -- bin/rails test test/integration/loops_contact_lifecycle_test.rb test/services/loops_contact_synchronizer_test.rb test/models/user/marketing_consent_test.rb`
4. **Review:** Run `review-changes-mini` once for Checkpoint 1, covering Tasks 1–2. If execution is delegated as a batch, the Master runs it once after all checkpoint work returns.

### Task 3 [subagent]: Add the resumable, throttled contact backfill job

**Skills:** write-tests
**Reference:** Follow the cursor pattern described in the COV-51 design, the `User.marketing_subscribed` scope in [`app/models/user/marketing_consent.rb`](../../app/models/user/marketing_consent.rb), and COV-50's throttler seam in [`app/clients/loops_client.rb`](../../app/clients/loops_client.rb)

**In scope:**

- Add `LoopsContactBackfillJob` with only the last examined user ID as its persisted argument.
- Validate production environment, enabled state, and mailing-list configuration again when the job runs.
- Select at most 100 currently consenting user IDs above the cursor in ascending order.
- Reload each selected user immediately before synchronization and reuse the synchronizer's `opt_in` behavior.
- Construct one Loops client per batch with a throttler that pauses 0.2 seconds before each request.
- Enqueue the next batch only after the current batch succeeds, using the last examined ID.
- Make retries idempotent and log batch start, progress, and completion.
- Apply the same transient retry policy as lifecycle jobs.

**NOT in scope:**

- Parallel contact requests, more than five requests per second, progress tables, locks, cancellation, admin UI, dynamic batch sizing, or deleting contacts.
- Backfilling users without current consent.
- Persisting progress anywhere except the next Active Job argument.

**Build order:**

1. **Test:** Add `test/jobs/loops_contact_backfill_job_test.rb` first. Prove:
   - Invalid runtime configuration fails before client construction or HTTP.
   - The query is ordered, cursor-exclusive, limited to 100, and contains only consenting candidates.
   - Each candidate is reloaded and skipped if consent changed before its turn.
   - One client is reused and receives a throttler whose interval is exactly 0.2 seconds.
   - Every actual request passes through that throttler, capping throughput at five per second.
   - A complete batch enqueues the next cursor only after all selected users succeed.
   - Empty/final batches log completion without duplicate work.
   - A mid-batch transient failure schedules retry and never advances the cursor.
   - Reprocessing earlier successful upserts during retry is harmless.
2. **Implement:** Add `app/jobs/loops_contact_backfill_job.rb` with a named batch-size constant, narrow overridable seams for synchronizer/client/sleep testing, sequential processing, structured Loops contact-sync logging, and transient retry declarations.
3. **Verify:** `mise exec -- bin/rails test test/jobs/loops_contact_backfill_job_test.rb test/services/loops_contact_synchronizer_test.rb`

### Task 4 [subagent]: Add guarded dry-run and enqueue operations

**Skills:** write-tests
**Reference:** Read [`lib/tasks/active_storage.rake`](../../lib/tasks/active_storage.rake), [`lib/tasks/stimulus.rake`](../../lib/tasks/stimulus.rake), and the exact commands specified in the COV-51 design

**In scope:**

- Add `loops:contacts:backfill:dry_run`.
- Print environment, production status, enabled status, mailing-list configuration status, and current consenting-user count.
- Keep dry-run safe in every environment with no HTTP and no jobs.
- Add `loops:contacts:backfill:enqueue`.
- Reuse the synchronizer's readiness guard rather than duplicating environment logic.
- Enqueue the initial cursor job only after all three live guards pass.
- Print a concise confirmation identifying the environment and initial cursor.

**NOT in scope:**

- Running jobs inline, prompting for confirmation, accepting arbitrary environments, dashboard work, API keys, progress polling, cancellation, or adding bin scripts.
- Creating contacts during dry-run.
- Continuing after a failed guard.

**Build order:**

1. **Test:** Add `test/tasks/loops_contacts_test.rb` first. Reload tasks independently and capture output to prove:
   - Dry-run reports the exact current fixture count and all guard states.
   - Dry-run issues no Loops request and enqueues no job.
   - Live enqueue refuses non-production, disabled, and missing-list configurations independently.
   - Every refusal enqueues nothing and produces a clear reason.
   - A ready production configuration enqueues exactly one `LoopsContactBackfillJob` with the initial cursor and performs no contact request itself.
2. **Implement:** Add `lib/tasks/loops_contacts.rake` with the nested `loops:contacts:backfill` namespace and the exact `dry_run` and `enqueue` task names from the design.
3. **Verify:** `mise exec -- bin/rails test test/tasks/loops_contacts_test.rb test/jobs/loops_contact_backfill_job_test.rb`
4. **Review:** Run `review-changes-mini` once for Checkpoint 2, covering Tasks 3–4. If these tasks were delegated sequentially, the Master runs the review after both return.

### Task 5 [Master]: Run integrated verification and final review

**Skills:** review-changes-mini
**Reference:** Re-read every acceptance criterion in [`docs/designs/cov-51-sync-users-to-loops-contacts.md`](../designs/cov-51-sync-users-to-loops-contacts.md)

**In scope:**

- Verify production-only guards, exact payloads, lifecycle isolation, stale ordering, deletion, retries, cursor behavior, and throttling as one feature.
- Confirm registration/settings record changes never make synchronous Loops requests.
- Confirm transactional email behavior remains independent of marketing consent.
- Review every changed file for personal-data minimization and exact job arguments.
- Make only test-first corrections required by COV-51 failures.

**NOT in scope:**

- COV-52 webhooks/reconciliation, COV-54 events, additional mailing lists, UI changes, migrations, new dependencies, speculative cleanup, or live Loops writes.
- Changing COV-50 client behavior unless a regression proves its existing documented seam is broken.

**Build order:**

1. **Test:** Run focused contact-sync tests, then `mise exec -- bin/rails test`.
2. **Implement:** If verification exposes a COV-51 defect, add or tighten the smallest focused regression test first, make the minimum correction, and rerun that focused file.
3. **Verify:** Run:
   - `mise exec -- ruby -v`
   - `mise exec -- bin/rails test test/services/loops_contact_synchronizer_test.rb test/integration/loops_contact_lifecycle_test.rb test/jobs/loops_contact_backfill_job_test.rb test/tasks/loops_contacts_test.rb`
   - `mise exec -- bin/rails test`
   - `mise exec -- bin/rubocop`
   - `git diff --check`
   - `git status --short`
   - `git diff`
   - `git diff origin/main...HEAD`
4. **Review:** Run `review-changes-mini` once for Checkpoint 3, covering Task 5 and the integrated final diff.

## Task Dependencies

- Task 1 is first because every job and operation depends on its payload rules and centralized environment/configuration guard.
- Task 2 depends on Task 1 and establishes all routine lifecycle and deletion behavior.
- Task 3 depends on Tasks 1–2 because it reuses the synchronizer's current-state checks, client injection, retry policy, and opt-in payload.
- Task 4 depends on Task 3 because its live operation enqueues `LoopsContactBackfillJob`; it can be delegated after that job exists.
- Task 5 depends on Tasks 1–4 and remains with Master because it owns whole-feature acceptance verification and the final diff.
- The two subagent tasks are sequential, not parallel: Task 4 requires Task 3's job class and focused tests.
- No implementation task touches more than four files. Phase 1 is deployable lifecycle synchronization and deletion; Phase 2 adds optional backfill operations; Phase 3 verifies the combined feature.
