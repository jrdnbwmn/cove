> Ticket: COV-97
> Branch: fix/cov-97-code-review

# Plan: Code review fixes (COV-97)

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | 1     | 1          | Block invitations into archived families; clear them on archive (F1) | Master | ✅   |
| 2    | 1     | 1          | Signup-by-invite surfaces acceptance failures; ignore archived invites (F1, F6) | Clone  | ✅   |
| 3    | 1     | 1          | Allow inviting existing users; acceptance decides (F2, F11) | Master | ✅   |
| 4    | 1     | 2          | A canceled subscription in its final paid period doesn't block joining (F3) | Master | ✅   |
| 5    | 1     | 2          | Lock families in ID order; handle deadlocks gracefully (F14) | Master | ✅   |
| 6    | 2     | 3          | Retry failed Loops webhook events; prune only processed rows (F4) | Master |      |
| 7    | 2     | 3          | Daily sweep re-enqueues stranded Loops webhook events (F4) | Master |      |
| 8    | 2     | 4          | Case-insensitive email lookup in the Loops webhook processor (F15) | Clone  |      |
| 9    | 2     | 4          | HTTPS mailer links; fix stale render.yaml comment (F9, F16) | Clone  |      |
| 10   | 3     | 5          | Family deletion cancels every live subscription status (F8) | Master |      |
| 11   | 3     | 5          | Family deletion handles Stripe failures and failed destroys (F8) | Clone  |      |
| 12   | 3     | 5          | Ownership transfer requires sign-in (F10) | Clone  |      |
| 13   | 3     | 6          | Checkout: hidden plans admin-only; fixed error messages (F12) | Master |      |
| 14   | 3     | 6          | Change-plan page handles a subscription with no matching plan (F13) | Clone  |      |
| 15   | 4     | 7          | Remove the modern-browser gate (F7) | Master |      |
| 16   | 4     | 7          | Move family/invite model + service messages to i18n (F17) | Master |      |
| 17   | 4     | 7          | Move family/invite controller messages to i18n (F17) | Clone  |      |
| 18   | 4     | 8          | Signup completion: current status symbol + `params.expect` (F18) | Clone  |      |
| 19   | 4     | 8          | Skip nil recipients on invite-accepted notifications (F23) | Clone  |      |
| 20   | 4     | 8          | Madmin account: owner/personal read-only, show archived_at (F22) | Clone  |      |
| 21   | 4     | 9          | NOT NULL constraints on membership columns (F21) | Master |      |

## Prerequisites

- Design: the COV-97 read-only code review from the conversation in which this plan was written (findings F1–F24). No separate design doc.
- Prototype: None.
- Feature branch exists: `fix/cov-97-code-review`.
- Environment: run `export PATH="$HOME/.local/share/mise/shims:$PATH"` before any `bin/rails` / `bin/rubocop` command and confirm `ruby -v` reports 4.0.5 (see AGENTS.md "Environment").
- Baseline before starting: `bin/rails test` → 905 runs, 0 failures (recorded at review time).

### Product decisions already made (do not re-litigate)

- **F2:** Follow the product brief. Existing users can be invited; acceptance decides and shows the specific reason if they can't join.
- **F3:** A subscription that is already canceled but still inside its paid period does **not** block joining another family.
- **F5:** Production Active Storage on Render's disk is **deferred to the production cutover ticket**. Not in this plan.
- **F7:** Remove the browser-version gate everywhere.

### Findings intentionally not changed (no task)

- **F5** — deferred (see above).
- **F11** — editing an invitation could bypass the "existing user" check. Task 3 removes that check, so there's nothing left to bypass.
- **F19** — `Account#joinable_by?`, `#students_allowed`, `PremiumAccess#require_premium!`, `students_empty?`'s `respond_to?` placeholder. They're kept for the upcoming Students ticket. Note: Task 4 changes `unjoinable_reason`, which `joinable_by?` wraps, so it stays correct.
- **F20** — committed `.Codex/` files. Whether they're scratch files or intentionally shared is Jordan's call; not touched.
- **F24** — `PlanPricingHelper#monthly_equivalent` hardcoding `$` (app is USD-only), and `Pay::Subscription#plan` memoization (no caller reads it after `swap`). No change.

### Rules that apply to every task

- TDD: write the failing test first, watch it fail, then implement (write-tests skill).
- Test names describe user-facing behavior ("a parent can't join an archived family"), not methods.
- Files under `lib/jumpstart/` are vendored engine code. When you change one, add a `# AIDEV-NOTE: Local change (COV-97) to Jumpstart: <why>` comment matching the existing COV-94 notes.
- Fixtures only, no FactoryBot. Associations by label. See AGENTS.md "Test data".
- Clones: do not commit. Stage changes and report.
- After any migration, `git diff` the four schema dumps and `git checkout --` any that only show reordering / version-bump noise (AGENTS.md "Known Gotchas").

## Tasks

## Phase 1: Family membership correctness

### Task 1 [Master]: Block invitations into archived families; clear them on archive

**Skills:** write-tests
**Reference:** Read `app/services/family_invitation_acceptance.rb`, `test/services/family_invitation_acceptance_test.rb`, `app/models/account.rb` (`active` / `archived` scopes, `archive!`).

**Background (F1, confirmed bug):** When user A joins another family, A's old family is archived (service lines 32-33) but its pending invitations remain. If someone accepts one, they become a member of an archived family: `User#family` returns nil, and every request then runs `set_fallback_account` → `create_default_account`, which raises `RecordInvalid` (unique index on `account_users.user_id`). The user gets a 500 on every page, forever.

**In scope:**

- In `FamilyInvitationAcceptance#call`, right after `target = invitation.account.lock!`, return `Result.new(nil, "This invitation is no longer valid")` when `target.archived_at.present?`.
- When archiving the source family (line 33), also destroy the source family's pending invitations (`source.account_invitations.destroy_all`) in the same transaction.
- Tests in `test/services/family_invitation_acceptance_test.rb`:
  - "a parent can't accept an invitation from an archived family": build an archived family with a pending invitation; assert the result fails with that message, no `AccountUser` is created, and the invitation still exists.
  - "joining a new family withdraws the old family's pending invitations": user whose empty family has a pending invitation accepts another family's invite; assert the old family's invitation is gone.
- After implementing, run this read-only check in the dev console and report the result in your task report. Do not write a data fix:
  `AccountUser.joins(:account).where.not(accounts: {archived_at: nil}).count` (expected 0).

**NOT in scope:**

- Controller changes (Task 2).
- Changing the subscription rule (Task 4) or lock order (Task 5).
- i18n of the message (Task 16).

**Build order:**

1. **Test:** add both tests above to `test/services/family_invitation_acceptance_test.rb`; confirm they fail.
2. **Implement:** `app/services/family_invitation_acceptance.rb`.
3. **Verify:** `bin/rails test test/services/family_invitation_acceptance_test.rb test/models/account_invitation_test.rb test/integration/loops_plan_status_sync_test.rb`

### Task 2 [Clone]: Signup-by-invite surfaces acceptance failures; ignore archived invites

**Skills:** write-tests
**Reference:** Read `app/controllers/users/registrations_controller.rb`, `app/controllers/account_invitations_controller.rb`, `test/integration/account_invitations_test.rb` (see "accepts invitation automatically through sign up").

**Background (F6):** `Users::RegistrationsController#sign_up` ignores the return value of `@account_invitation.accept!`. If acceptance fails, the new parent silently gets their own solo family on the next request and no message.

**In scope:**

- `registrations_controller.rb#sign_up`: if `accept!` returns nil, set `flash[:alert]` to `@account_invitation.errors.full_messages.first`. Keep the existing `stored_location_for(:user)` clear.
- `registrations_controller.rb#build_resource`: only use the invitation if its account is active. Use `AccountInvitation.joins(:account).merge(Account.active).find_by(token: params[:invite])`.
- `account_invitations_controller.rb#set_account_invitation`: same active-account scoping, so an archived family's invitation shows the existing "not found" redirect.
- Tests in `test/integration/account_invitations_test.rb`:
  - "signing up from an invitation to a full family explains why the parent wasn't added": the invite's family fills before signup; assert the alert flash text.
  - "an invitation from an archived family is treated as not found": GET the invitation path while signed in; assert redirect to root with the not-found alert.

**NOT in scope:**

- Changing `FamilyInvitationAcceptance` (Task 1).
- New copy or i18n keys beyond reusing existing ones (Task 17 does i18n).

**Build order:**

1. **Test:** add the two tests to `test/integration/account_invitations_test.rb`; confirm they fail.
2. **Implement:** `app/controllers/users/registrations_controller.rb`, `app/controllers/account_invitations_controller.rb`.
3. **Verify:** `bin/rails test test/integration/account_invitations_test.rb test/controllers/users/registrations_controller_test.rb`

### Task 3 [Master]: Allow inviting existing users; acceptance decides

**Skills:** write-tests
**Reference:** Read `app/controllers/accounts/account_invitations_controller.rb`, `test/integration/accounts/account_invitations_test.rb`, `docs/product/product-brief.md` ("Families").

**Background (F2, decision: follow the brief):** `create` rejects any email belonging to a registered user (`User.by_email(...).joins(:accounts).exists?`, lines 17-20). Every user has a family, so this blocks everyone. But the brief says an existing user with an empty family may accept an invite. `FamilyInvitationAcceptance` already enforces the real rules (other members → contact support; subscription → cancel first) with specific messages.

**In scope:**

- Delete the existing-user check (lines 17-20) from `Accounts::AccountInvitationsController#create`. Keep the capacity check (lines 12-15).
- Tests in `test/integration/accounts/account_invitations_test.rb`:
  - "a parent can invite someone who already has a Cove login": invite an existing user's email; assert the invitation is created and the email enqueued.
  - "an invited parent with an empty family joins and their old family is archived": end-to-end through `PATCH account_invitation_path` signed in as that user. Assert they now belong to the inviting family and the old family is archived.
  - "an invited parent whose family has another parent is told to contact support": assert the alert text from `FamilyInvitationAcceptance`.

**NOT in scope:**

- Changing acceptance rules (Tasks 1, 4).
- Changing the product brief (it already describes this behavior).
- Changing the invitation `update` action (F11 is moot once this check is gone).

**Build order:**

1. **Test:** add the three tests; confirm the first fails.
2. **Implement:** `app/controllers/accounts/account_invitations_controller.rb`.
3. **Verify:** `bin/rails test test/integration/accounts/account_invitations_test.rb test/integration/account_invitations_test.rb`
4. **Review:** run review-changes-mini for **Checkpoint 1 (Tasks 1–3)** when this task's work is finished. If Checkpoint 1's tasks were executed as a parallel batch, the master runs this review once the whole batch returns instead. Either way it runs exactly once, after all of Tasks 1–3 are done.

### Task 4 [Master]: A canceled subscription in its final paid period doesn't block joining

**Skills:** write-tests
**Reference:** Read `app/models/account.rb` (`unjoinable_reason`, `billable_subscriptions`), `test/models/account_test.rb` (joinable tests near line 350), `test/fixtures/pay/subscriptions.yml`, Pay 11.6.2 scopes (`active` includes `ends_at > now`; `on_grace_period` = `ends_at IS NOT NULL AND ends_at > now`).

**Background (F3, decision: allow joining):** `unjoinable_reason` returns `:billable_subscription` for any `active`/`past_due` subscription. Pay's `active` scope includes subscriptions already canceled at period end. So a parent who follows the "Cancel your Premium subscription first" message is still blocked for up to a year.

**In scope:**

- In `Account#unjoinable_reason`, only block on subscriptions that will renew. Add a private method `renewing_subscriptions` = `billable_subscriptions.where(ends_at: nil)` and use it on line 76.
- Do **not** change `billable_subscriptions` itself. It also drives `paid_premium?` and family deletion.
- Add an `# AIDEV-NOTE:` explaining that a canceled-but-still-paid subscription stays with the archived family and simply runs out.
- Add a fixture if needed (e.g. `on_grace_period` in `test/fixtures/pay/subscriptions.yml`, `ends_at: <%= 1.month.from_now %>`, status `active`), attached via existing customer fixtures by label.
- Tests:
  - `test/models/account_test.rb`: "a family whose Premium is canceled but still paid through the period is joinable"; "a family with a renewing subscription is not joinable" (keep or extend the existing case).
  - `test/services/family_invitation_acceptance_test.rb`: "a parent who canceled Premium can join another family; the old family keeps its subscription record".
- Update `docs/product/product-brief.md` ("Families" bullet): "An active subscription must be canceled first" → a subscription must be canceled first, and a canceled subscription still in its paid period doesn't block joining.

**NOT in scope:**

- `paid_premium?`, `plan_status`, or deletion behavior.
- Message copy changes.

**Build order:**

1. **Test:** add the tests (and fixture); confirm the grace-period cases fail.
2. **Implement:** `app/models/account.rb`; update `docs/product/product-brief.md`.
3. **Verify:** `bin/rails test test/models/account_test.rb test/services/family_invitation_acceptance_test.rb test/config/seeds_test.rb`

### Task 5 [Master]: Lock families in ID order; handle deadlocks gracefully

**Skills:** write-tests
**Reference:** Read `app/services/family_invitation_acceptance.rb` (after Tasks 1 and 4), `test/services/family_invitation_acceptance_test.rb`.

**Background (F14):** The service locks the target family, then the source family. If two single-parent families accept each other's invitations at the same moment, they lock in opposite orders and Postgres raises `ActiveRecord::Deadlocked`. That isn't rescued, so the user gets a 500.

**In scope:**

- Reorder locking inside the transaction: `invitation.lock!`, `user.lock!`, then look up `target = invitation.account` and `source = user.family`. Lock `[target, source].compact.uniq.sort_by(&:id)` in that order.
- Keep all checks after the locks, with the same messages and order: archived (Task 1), full, same family, unjoinable.
- `rescue ActiveRecord::Deadlocked` → `Result.new(nil, "Something changed while joining. Please try again.")`.
- Test: "a parent sees a try-again message if joining collides with another change". Stub `Account#lock!` to raise `ActiveRecord::Deadlocked` once (Minitest `stub`), and assert the failure result and no membership change.

**NOT in scope:**

- Multi-threaded concurrency tests.
- i18n (Task 16).

**Build order:**

1. **Test:** add the deadlock test; confirm it fails (raises).
2. **Implement:** `app/services/family_invitation_acceptance.rb`.
3. **Verify:** `bin/rails test test/services/family_invitation_acceptance_test.rb test/integration/account_invitations_test.rb test/integration/accounts/account_invitations_test.rb`
4. **Review:** run review-changes-mini for **Checkpoint 2 (Tasks 4–5)** when this task's work is finished. If Checkpoint 2's tasks were executed as a parallel batch, the master runs this review once the whole batch returns instead. Either way it runs exactly once, after all of Tasks 4–5 are done.

## Phase 2: Loops webhook reliability and config

### Task 6 [Master]: Retry failed Loops webhook events; prune only processed rows

**Skills:** write-tests
**Reference:** Read `app/jobs/loops_webhook_event_job.rb`, `app/jobs/loops_webhook_event_pruning_job.rb`, `app/jobs/concerns/loops_retryable.rb` (retry style), `test/jobs/loops_webhook_event_job_test.rb`, `test/jobs/loops_webhook_event_pruning_job_test.rb`, `test/fixtures/loops_webhook_events.yml`.

**Background (F4):** The job's comment says failures stay "retryable by a subsequent job attempt", but `ApplicationJob` has no `retry_on` and nothing re-enqueues. The pruning job then deletes the event after 30 days whether or not it was processed. One transient error can drop an unsubscribe or spam complaint.

**In scope:**

- `LoopsWebhookEventJob`: add `retry_on StandardError, wait: :polynomially_longer, attempts: 10`. This is safe because the job already returns early when `processed_at` is set. Rewrite the AIDEV-NOTE to describe the real behavior (Active Job retries; Task 7's sweep covers events whose job was never enqueued).
- `LoopsWebhookEventPruningJob`: delete only processed rows: `LoopsWebhookEvent.prunable.where.not(processed_at: nil).delete_all`.
- Tests:
  - Job: "a webhook event that fails processing is retried" — stub `LoopsWebhookEventProcessor#call` to raise once, `assert_enqueued_with(job: LoopsWebhookEventJob)` after `perform_now`, and `processed_at` stays nil.
  - Pruning: "old unprocessed webhook events are kept for reprocessing". Add a fixture `old_unprocessed` (`created_at: <%= 40.days.ago %>`, `processed_at:` nil) and assert it survives while an old processed one is deleted.

**NOT in scope:**

- The sweep job (Task 7).
- Webhook signature/timestamp checks (security audit).

**Build order:**

1. **Test:** add both tests and the fixture; confirm they fail.
2. **Implement:** the two job files.
3. **Verify:** `bin/rails test test/jobs/loops_webhook_event_job_test.rb test/jobs/loops_webhook_event_pruning_job_test.rb test/integration/loops_webhook_test.rb`

### Task 7 [Master]: Daily sweep re-enqueues stranded Loops webhook events

**Skills:** write-tests
**Reference:** Read `config/recurring.yml`, `app/models/loops_webhook_event.rb` (`unprocessed` scope), `app/controllers/inbound_webhooks/loops_controller.rb` (lines 26-37).

**Background (F4):** If `perform_later` fails after the row is saved, the controller returns a 500 and Loops retries. The retry then hits `RecordNotUnique` and returns 200, so the event is never processed. Something has to pick up these stranded rows.

**In scope:**

- New `app/jobs/loops_webhook_event_sweep_job.rb`: enqueue `LoopsWebhookEventJob` for each `LoopsWebhookEvent.unprocessed.where(created_at: 7.days.ago..1.hour.ago)` (use `find_each`). Add an AIDEV-NOTE explaining the stranded-row case above and why the window is bounded (so an event that fails permanently doesn't loop forever).
- `config/recurring.yml` (production section): add `loops_webhook_event_sweep` with `class: LoopsWebhookEventSweepJob`, `queue: background`, `schedule: every day at 4am`.
- Test `test/jobs/loops_webhook_event_sweep_job_test.rb`: "stranded webhook events are queued for processing again". Cover: an unprocessed event 2 hours old is enqueued; one 5 minutes old, one processed, and one 10 days old are not.

**NOT in scope:**

- Honeybadger alerting changes (exhausted retries already report through Active Job).
- Staging job adapter (staging runs `:async` and doesn't run recurring jobs; accepted).

**Build order:**

1. **Test:** create the sweep job test; confirm it fails.
2. **Implement:** the job file; `config/recurring.yml`.
3. **Verify:** `bin/rails test test/jobs/loops_webhook_event_sweep_job_test.rb test/config`
4. **Review:** run review-changes-mini for **Checkpoint 3 (Tasks 6–7)** when this task's work is finished. If Checkpoint 3's tasks were executed as a parallel batch, the master runs this review once the whole batch returns instead. Either way it runs exactly once, after all of Tasks 6–7 are done.

### Task 8 [Clone]: Case-insensitive email lookup in the Loops webhook processor

**Skills:** write-tests
**Reference:** Read `app/services/loops_webhook_event_processor.rb` (`find_user`), `app/models/user.rb` (`by_email` scope), `test/services/loops_webhook_event_processor_test.rb`.

**In scope:**

- In `find_user`, replace `User.find_by(email: email)` with `User.by_email(email).first`.
- Test: "an unsubscribe for a mixed-case email still opts the parent out". Payload `contactIdentity: {"email" => user.email.upcase}` with no userId; assert `marketing_opt_out_at` is set.

**NOT in scope:**

- Any other lookup or opt-out logic.

**Build order:**

1. **Test:** add the test to `test/services/loops_webhook_event_processor_test.rb`; confirm it fails.
2. **Implement:** `app/services/loops_webhook_event_processor.rb`.
3. **Verify:** `bin/rails test test/services/loops_webhook_event_processor_test.rb`

### Task 9 [Clone]: HTTPS mailer links; fix stale render.yaml comment

**Skills:** write-tests
**Reference:** Read `config/environments/production.rb`, `config/environments/staging.rb` (`default_url_options` lines), `render.yaml` (`SOLID_QUEUE_IN_PUMA` comment in the staging service), `test/config/job_adapter_test.rb` (file-reading test pattern), `test/config/render_blueprint_test.rb`.

**Background (F9, F16):** Mailer `default_url_options` has no protocol, so invite and password-reset links start with `http://`. The staging `render.yaml` comment says "this app has no custom background jobs yet", which is no longer true (there are seven Loops jobs).

**In scope:**

- `production.rb`: `config.action_mailer.default_url_options = {host: Jumpstart.config.domain, protocol: "https"}`.
- `staging.rb`: add `protocol: "https"` to both the `action_mailer` and `action_controller` `default_url_options`.
- `render.yaml`: reword the comment so the reason for leaving `SOLID_QUEUE_IN_PUMA` off is memory only. Note that staging runs jobs with the `:async` adapter (in-process, lost on restart). Don't change any keys or values.
- New `test/config/mailer_url_options_test.rb` (plain `Minitest::Test`, file-reading pattern from `job_adapter_test.rb`): "production and staging emails link over https". Assert both files contain `protocol: "https"` on their `default_url_options` lines.

**NOT in scope:**

- Changing the job adapter or any Render service settings.
- Production Active Storage (F5, deferred).

**Build order:**

1. **Test:** create `test/config/mailer_url_options_test.rb`; confirm it fails.
2. **Implement:** the three config files.
3. **Verify:** `bin/rails test test/config`
4. **Review:** run review-changes-mini for **Checkpoint 4 (Tasks 8–9)** when this task's work is finished. If Checkpoint 4's tasks were executed as a parallel batch, the master runs this review once the whole batch returns instead. Either way it runs exactly once, after all of Tasks 8–9 are done.

## Phase 3: Billing and account edge cases

### Task 10 [Master]: Family deletion cancels every live subscription status

**Skills:** write-tests
**Reference:** Read `app/models/account.rb` (`cancel_billable_subscriptions!`, `billable_subscriptions`), `test/models/account_test.rb` (deletion tests near lines 380-420 and the `stub_cancel_now` / `stub_stripe_release` helpers).

**Background (F8):** Deleting a family only cancels `active`/`past_due` subscriptions. `unpaid`, `incomplete` and `paused` ones stay alive in Stripe after the family is gone. The brief says deleting a family ends its subscription immediately.

**In scope:**

- Add a private `live_subscriptions` = `pay_subscriptions.where.not(status: %w[canceled incomplete_expired])` and use it in the `before_destroy` callback in place of `billable_subscriptions`. Rename the callback to `cancel_live_subscriptions!` and update the `before_destroy` line.
- Keep the existing release-schedule-then-`cancel_now!` loop and its AIDEV-NOTE.
- Tests: "deleting a family with an unpaid subscription cancels it in Stripe", and the same for `incomplete`. Reuse `stub_cancel_now`; set status on a fixture subscription with `update_columns`.

**NOT in scope:**

- `billable_subscriptions`, `paid_premium?`, joinability.
- Deleting or keeping `Pay::Customer` rows (they're left in place on purpose; no decision needed now).
- Moving Stripe calls out of the destroy transaction.

**Build order:**

1. **Test:** add the tests; confirm they fail.
2. **Implement:** `app/models/account.rb`.
3. **Verify:** `bin/rails test test/models/account_test.rb`

### Task 11 [Clone]: Family deletion handles Stripe failures and failed destroys

**Skills:** write-tests
**Reference:** Read `app/controllers/accounts_controller.rb` (`destroy`), `config/locales/en.yml` (`accounts:` block near line 91), `app/controllers/billing/subscriptions/plan_changes_controller.rb` (log-and-fixed-message pattern), `test/integration/accounts_test.rb`.

**Background (F8):** `@account.destroy` ignores its return value, and a `Pay::Error` from Stripe during cancellation produces a 500.

**In scope:**

- `AccountsController#destroy`: on success, keep the current redirect. If `destroy` returns false, redirect to `edit_account_path(@account)` with `alert: t(".failure")`.
- `rescue Pay::Error => e` → `Rails.logger.error("[Accounts] Could not delete family #{@account.id}: #{e.message}")`, then the same failure redirect.
- Add `accounts.destroy.failure` to `config/locales/en.yml`: "We couldn't delete your family right now. Please try again or contact support."
- Test in `test/integration/accounts_test.rb`: "a family owner sees a calm error if billing can't be canceled during deletion". Stub the Stripe cancel request to return 500 with WebMock; assert redirect, flash, and that the account still exists.

**NOT in scope:**

- Model changes (Task 10).

**Build order:**

1. **Test:** add the test; confirm it fails.
2. **Implement:** `app/controllers/accounts_controller.rb`, `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/integration/accounts_test.rb test/integration/billing_policy_copy_test.rb`

### Task 12 [Clone]: Ownership transfer requires sign-in

**Skills:** write-tests
**Reference:** Read `app/controllers/accounts/transfers_controller.rb`, `app/controllers/accounts_controller.rb` (`before_action :authenticate_user!` style).

**Background (F10):** There's no `authenticate_user!`, so a signed-out PATCH calls `nil.owned_accounts` and returns a 500.

**In scope:**

- Add `before_action :authenticate_user!` as the first callback.
- Test (add to `test/integration/accounts_test.rb`, or create `test/integration/accounts/transfers_test.rb`): "a signed-out visitor trying to transfer a family is sent to sign in". PATCH `account_transfer_path(accounts(:company), user_id: ...)` signed out; assert redirect to `new_user_session_path`.

**NOT in scope:**

- The engine's `Account#transfer_ownership` bare `rescue`.

**Build order:**

1. **Test:** add the test; confirm it fails (500).
2. **Implement:** `app/controllers/accounts/transfers_controller.rb`.
3. **Verify:** run the test file you added to.
4. **Review:** run review-changes-mini for **Checkpoint 5 (Tasks 10–12)** when this task's work is finished. If Checkpoint 5's tasks were executed as a parallel batch, the master runs this review once the whole batch returns instead. Either way it runs exactly once, after all of Tasks 10–12 are done.

### Task 13 [Master]: Checkout: hidden plans admin-only; fixed error messages

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/controllers/checkouts_controller.rb`, `app/controllers/concerns/plan_change_guard.rb` (hidden-plan rationale), `lib/jumpstart/app/controllers/billing/subscriptions_controller.rb` (COV-94 log + fixed message pattern), `config/locales/en.yml` (`checkouts:` near line 530), `test/integration/checkouts_test.rb`.

**Background (F12):** Checkout accepts hidden plans, so a hand-built URL can subscribe at a retired price, unlike the plan-change guard. Error paths also flash Stripe's raw `e.message`, which COV-94 removed everywhere else.

**In scope:**

- `set_plan`: `Plan.visible.find_by_prefix_id!` for everyone except system admins (`current_user&.admin?`), who keep `Plan.find_by_prefix_id!` (preserves the "customer support" intent in the existing comment). Update that comment and add an `AIDEV-NOTE: Local change (COV-97)`.
- Both `rescue Pay::Error` blocks: log `"[Checkouts] ... #{e.message}"` and use `t(".failure")` instead of `e.message`.
- Add `checkouts.show.failure` and `checkouts.create.failure` to `en.yml` ("We couldn't start checkout. Please try again.").
- Tests in `test/integration/checkouts_test.rb`:
  - "a parent can't check out a hidden plan" → redirect to pricing.
  - "a superadmin can open checkout for a hidden plan".
  - "checkout errors show a friendly message instead of Stripe's" → stub a Stripe error and assert flash text doesn't include the stubbed Stripe message.

**NOT in scope:**

- `metadata.permit!` (security audit).
- Braintree / Lemon Squeezy branches beyond the shared rescue.

**Build order:**

1. **Test:** add the tests; confirm they fail.
2. **Implement:** `lib/jumpstart/app/controllers/checkouts_controller.rb`, `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/integration/checkouts_test.rb test/integration/plans_test.rb`

### Task 14 [Clone]: Change-plan page handles a subscription with no matching plan

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/controllers/billing/subscriptions_controller.rb` (`edit`, lines 19-25), `test/integration/subscriptions_test.rb`.

**Background (F13):** If no Plan row matches the subscription's Stripe price, `@current_plan.id` raises `NoMethodError`.

**In scope:**

- At the top of `edit`, if `@subscription.plan` is nil, redirect to `billing_path` with `alert: t("billing.subscriptions.plan_change_guard.unavailable")` (existing key) and return. Add `AIDEV-NOTE: Local change (COV-97)`.
- Test: "a parent whose subscription price isn't in the plan catalog is sent back to billing". `update_columns(processor_plan: "price_unknown")` on a fixture subscription; GET edit; assert redirect.

**NOT in scope:**

- `update` (already redirects via `find_plan_change_target`).

**Build order:**

1. **Test:** add the test to `test/integration/subscriptions_test.rb`; confirm it fails.
2. **Implement:** the controller.
3. **Verify:** `bin/rails test test/integration/subscriptions_test.rb test/integration/subscription_plan_changes_test.rb`
4. **Review:** run review-changes-mini for **Checkpoint 6 (Tasks 13–14)** when this task's work is finished. If Checkpoint 6's tasks were executed as a parallel batch, the master runs this review once the whole batch returns instead. Either way it runs exactly once, after all of Tasks 13–14 are done.

## Phase 4: Cleanup and consistency

### Task 15 [Master]: Remove the modern-browser gate

**Skills:** write-tests
**Reference:** Read `app/controllers/application_controller.rb`, `test/integration/public_test.rb`, `test/integration/static_error_pages_test.rb`.

**Background (F7, decision: remove everywhere):** `allow_browser versions: :modern` returns a 406 to Safari below 17.2 (older iPads/iPhones), even on the homepage and pricing.

**In scope:**

- Delete line 3 (and its comment on line 2) from `ApplicationController`.
- Test in `test/integration/public_test.rb`: "visitors on an older iPad can see the homepage". GET `root_path` with an iOS 16 Safari `User-Agent` header (e.g. `Mozilla/5.0 (iPad; CPU OS 16_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1`); assert 200.

**NOT in scope:**

- `public/406-unsupported-browser.html` and its test. Leave both in place.

**Build order:**

1. **Test:** add the test; confirm it fails with 406.
2. **Implement:** `app/controllers/application_controller.rb`.
3. **Verify:** `bin/rails test test/integration/public_test.rb test/integration/static_error_pages_test.rb`

### Task 16 [Master]: Move family/invite model + service messages to i18n

**Skills:** write-tests
**Reference:** Read `app/services/family_invitation_acceptance.rb` (after Tasks 1, 4, 5), `app/models/account_user.rb` (lines 18, 24), `config/locales/en.yml` (structure; `activerecord:` near line 675).

**Background (F17):** These user-facing strings are hardcoded English, and "Family already has two parents" is repeated in three places.

**In scope:**

- Add a `family_invitation_acceptance:` block to `en.yml` with keys: `wrong_recipient`, `archived`, `full`, `already_member`, `other_members`, `billable_subscription`, `try_again`. Use the exact current English copy, plus Task 1's and Task 5's new strings. Use `I18n.t("family_invitation_acceptance.<key>")` in the service.
- `AccountUser`: move both messages to `activerecord.errors.models.account_user.attributes.user.other_family` and `...account_user.attributes.base.full` (or equivalent), and use `errors.add(:user, :other_family)` / `errors.add(:base, :full)`. Rendered copy must stay identical.
- Existing tests that assert the literal strings must pass unchanged. That's the test for this task, since the copy doesn't change.

**NOT in scope:**

- Controller strings (Task 17).
- Changing any wording.

**Build order:**

1. **Test:** run `bin/rails test test/services/family_invitation_acceptance_test.rb test/models/account_user_test.rb` first to record the baseline.
2. **Implement:** the service, `app/models/account_user.rb`, `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/services/family_invitation_acceptance_test.rb test/models/account_user_test.rb test/integration/account_invitations_test.rb test/integration/accounts/account_invitations_test.rb`

### Task 17 [Clone]: Move family/invite controller messages to i18n

**Skills:** write-tests
**Reference:** Read `app/controllers/accounts/account_invitations_controller.rb` (line 13), `app/controllers/users/registrations_controller.rb` (line 9), `app/controllers/api/v1/me_controller.rb` (line 8), `config/locales/en.yml` (the `account_invitations:` and `users:` blocks; how lazy `t(".key")` keys are nested for these controllers).

**In scope:**

- Replace the hardcoded strings with `t(...)` lookups:
  - "Family already has two parents" → reuse the `family_invitation_acceptance.full` key from Task 16.
  - "Transfer family ownership before deleting your login" → one new key, e.g. `users.transfer_family_before_deletion`, used by both registrations and the API controller.
- English copy must not change.
- Existing tests asserting these strings must still pass.

**NOT in scope:**

- Service and model strings (Task 16).
- Engine controllers.

**Build order:**

1. **Test:** run the related tests for a baseline (`test/integration/accounts/account_invitations_test.rb`, `test/controllers/users/registrations_controller_test.rb`, `test/controllers/api`).
2. **Implement:** the three controllers and `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/integration/accounts/account_invitations_test.rb test/controllers/users/registrations_controller_test.rb test/controllers/api`
4. **Review:** run review-changes-mini for **Checkpoint 7 (Tasks 15–17)** when this task's work is finished. If Checkpoint 7's tasks were executed as a parallel batch, the master runs this review once the whole batch returns instead. Either way it runs exactly once, after all of Tasks 15–17 are done.

### Task 18 [Clone]: Signup completion: current status symbol + `params.expect`

**Skills:** write-tests
**Reference:** Read `app/controllers/users/signup_completions_controller.rb`, `test/controllers/users/signup_completions_controller_test.rb`.

**In scope:**

- Replace both `:unprocessable_entity` with `:unprocessable_content` (lines 20, 34).
- Change `signup_completion_params` to `params.expect(user: [:first_name, :last_name])`.
- Existing tests must pass. Add one test if none exists: "a parent who leaves first name blank sees the form again with an error" (assert 422).

**NOT in scope:**

- Marketing-consent logic in `update`.

**Build order:**

1. **Test:** confirm or add the blank-name test.
2. **Implement:** the controller.
3. **Verify:** `bin/rails test test/controllers/users/signup_completions_controller_test.rb`

### Task 19 [Clone]: Skip nil recipients on invite-accepted notifications

**Skills:** write-tests
**Reference:** Read `app/models/account_invitation.rb` (line 23), `test/models/account_invitation_test.rb`.

**Background (F23):** If the inviter has deleted their login, `invited_by` is nil (FK nullify), and `[account.owner, invited_by].uniq` delivers to `nil`. That creates an empty `Noticed::Event`.

**In scope:**

- Change the line to `[account.owner, invited_by].compact.uniq.each`.
- Test: "accepting an invitation whose inviter is gone only notifies the family owner". Set `invited_by: nil` and assert `Noticed::Notification` count increases by 1 and no event has 0 notifications.

**NOT in scope:**

- The notifier class.

**Build order:**

1. **Test:** add the test; confirm it fails.
2. **Implement:** `app/models/account_invitation.rb`.
3. **Verify:** `bin/rails test test/models/account_invitation_test.rb`

### Task 20 [Clone]: Madmin account: owner/personal read-only, show archived_at

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/madmin/resources/account_resource.rb`, `test/integration/madmin/accounts_test.rb`.

**Background (F22):** A superadmin can set `owner` to someone who isn't a member, and editing `personal` triggers the DB check constraint (500). `archived_at` isn't visible.

**In scope:**

- `attribute :owner, form: false`, `attribute :personal, form: false`.
- Add `attribute :archived_at, form: false`.
- Add `AIDEV-NOTE: Local change (COV-97)` explaining that ownership changes go through the app's transfer flow.
- Tests in `test/integration/madmin/accounts_test.rb`: "the admin family edit form doesn't offer owner or personal fields" (assert the form inputs are absent); "the admin family page shows when a family was archived".

**NOT in scope:**

- Other Madmin resources.

**Build order:**

1. **Test:** add the tests; confirm they fail.
2. **Implement:** `lib/jumpstart/app/madmin/resources/account_resource.rb`.
3. **Verify:** `bin/rails test test/integration/madmin/accounts_test.rb`
4. **Review:** run review-changes-mini for **Checkpoint 8 (Tasks 18–20)** when this task's work is finished. If Checkpoint 8's tasks were executed as a parallel batch, the master runs this review once the whole batch returns instead. Either way it runs exactly once, after all of Tasks 18–20 are done.

### Task 21 [Master]: NOT NULL constraints on membership columns

**Skills:** safe-migration, write-tests
**Reference:** Read `db/migrate/20260916210158_enforce_family_account_constraints.rb` (style), `test/migrations/enforce_family_account_constraints_test.rb`, `db/schema.rb` (`account_users`, `accounts`).

**Background (F21):** `account_users.account_id`, `account_users.user_id` and `accounts.account_users_count` allow NULL. `Account#full?` raises `NoMethodError` on a nil count.

**In scope:**

- New migration:
  - Backfill `accounts.account_users_count` from a COUNT subquery where it's NULL.
  - `change_column_null :accounts, :account_users_count, false, 0`.
  - `change_column_null :account_users, :account_id, false` and `change_column_null :account_users, :user_id, false`.
  - Write a `down` that reverses all three.
- Before writing it, check that no `account_users` rows have NULL ids (`AccountUser.where(account_id: nil).or(AccountUser.where(user_id: nil)).count` in dev). If any exist, stop and ask Jordan.
- Test `test/migrations/<new>_test.rb`, following the existing migration test: assert the three columns are `null: false`.
- Update `db/schema.rb` via `bin/rails db:migrate`. Then revert the noise-only diffs in `db/cable_schema.rb`, `db/cache_schema.rb` and `db/queue_schema.rb`. In `db/schema.rb`, keep only the real changes and the version bump (AGENTS.md "Known Gotchas").

**NOT in scope:**

- Other columns or indexes.

**Build order:**

1. **Test:** write the migration test; confirm it fails.
2. **Implement:** migration; run it; clean the schema diffs.
3. **Verify:** `bin/rails test test/migrations test/models/account_test.rb test/models/account_user_test.rb`, then the full `bin/rails test`.
4. **Review:** run review-changes-mini for **Checkpoint 9 (Task 21)** when this task's work is finished. It runs exactly once for this checkpoint.

## Task Dependencies

- **Phase 1 is sequential through the acceptance service:**
  - Task 1 → Task 2 (Task 2 relies on the archived-family behavior and message).
  - Task 1 → Task 4 → Task 5. All three edit `family_invitation_acceptance.rb` and its test file; Task 5 reorders the checks Tasks 1 and 4 touch.
  - Task 3 is independent of Tasks 1, 2, 4 and 5 code-wise, and can run in parallel with Task 2.
- **Phase 2:**
  - Task 6 → Task 7 (the sweep relies on the retry semantics and AIDEV-NOTE from Task 6).
  - Tasks 8 and 9 are independent of each other and of Tasks 6–7, so they can run in parallel.
- **Phase 3:**
  - Task 10 → Task 11 (the controller test exercises the model's cancellation path).
  - Task 12 is independent.
  - Task 13 and Task 14 are independent, but both may touch `config/locales/en.yml` along with Task 11; run any `en.yml` edits sequentially.
- **Phase 4:**
  - Task 16 depends on Tasks 1, 4 and 5 (final service strings). Task 17 depends on Task 16 (it reuses Task 16's `full` key).
  - Tasks 16, 17, 11 and 13 all edit `config/locales/en.yml`, so never run them in parallel with each other.
  - Tasks 15, 18, 19 and 20 are independent and can run in parallel.
  - Task 21 (migration) runs last, alone.
- **Deployability:** each phase leaves the app working and tested on its own.
- **Final step after Task 21:** run the full `bin/rails test` and `bin/rails test:system` sequentially (never concurrently; AGENTS.md "System tests"), then `bin/rubocop` and `bin/erb_lint --lint-all`.
