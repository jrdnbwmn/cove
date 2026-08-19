> Ticket: COV-47
> Branch: feature/cov-47-e2e-transactional-email-verification

# Plan: End-to-end verification of all eleven transactional emails

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1  | 1 | 1 | Confirm staging mail config, set allowlist, audit staging users | Master | |
| 2  | 1 | 1 | Confirm Stripe test keys + webhook endpoint | Master | |
| 3  | 1 | 1 | Create Stripe test product/price and matching `Plan` | Master | |
| 4  | 1 | 2 | Create verification user + set `billing_email` | Master | |
| 5  | 2 | 2 | Subscribe → receipt (5); cancel → starts 1h clock; refund → refund (6) | Master | |
| 6  | 2 | 2 | Failed-payment and 3DS subscriptions → emails 7, 8 | Master | |
| 7  | 2 | 3 | Console sends for the three clock-dependent emails (9, 10, 11) | Master | |
| 8  | 3 | 3 | Password reset + change → emails 1, 2, and the reset-link check | Master | |
| 9  | 3 | 3 | Invitation via `save_and_send_invite` → email 3 + link check | Master | |
| 10 | 3 | 4 | Cancellation survey at +1h → email 4 | Master | |
| 11 | 4 | 4 | Stripe webhook replay → idempotency check | Master | |
| 12 | 4 | 4 | Forced Loops failure → Honeybadger check | Master | |
| 13 | 4 | 5 | Loops dashboard audit + collect message ids | Master | |
| 14 | 5 | 5 | Fill in results tables, open follow-up tickets for issues | Master | |
| 15 | 5 | 5 | Staging cleanup | Master | |

## Prerequisites

- Design: `docs/designs/cov-47-loops-verification.md`
- Prototype: None
- Feature branch exists: `feature/cov-47-e2e-transactional-email-verification` (current branch)
- Access needed before starting: Render dashboard (staging service, env vars, Shell tab, Logs), Stripe dashboard in **test mode**, the Gmail account for `<you>@gmail.com`, the Loops dashboard, Honeybadger.
- Substitute your real address for `<you>@gmail.com` everywhere below.

**Standing rule for every task:** this ticket changes no application code. If a step
reveals a bug, record it in the design doc's "Issues found" section and open a
follow-up ticket — do not fix it on this branch. Verification here is inbox receipt,
not `bin/rails test`; the only file that changes on this branch is the design doc's
results table.

**Timing constraints that shape the order:**

- Task 5's cancel starts a one-hour `deliver_later(wait: 1.hour)` timer that Task 10
  collects. Tasks 6–9 are meant to fill that hour.
- Task 11's replay must happen **within 24 hours** of Task 5's `charge.succeeded`, or
  Loops' idempotency window has expired and the test proves nothing.

## Tasks

### Task 1 [Master]: Confirm staging mail config, set the allowlist, audit staging users

**Skills:** none (operational)
**Reference:** Design §Phase 0.1–0.3; `config/environments/staging.rb`; COV-46's recipient guard.

**In scope:**

- In the Render staging shell → `bin/rails console`, confirm:
  ```ruby
  Rails.application.config.action_mailer.delivery_method      # => :loops
  Rails.application.config.action_mailer.perform_deliveries   # => true
  ENV["STAGING_EMAIL_RECIPIENT_ALLOWLIST"]
  ```
- In Render's env vars, set `STAGING_EMAIL_RECIPIENT_ALLOWLIST` to contain both
  addresses **literally** (the guard is exact-match and does not broaden
  plus-addressing):
  - `<you>@gmail.com`
  - `<you>+cov47billing@gmail.com`
- Wait for the restart to finish before anything else.
- Audit that no real third-party address sits in staging:
  ```ruby
  User.pluck(:email)
  Account.where.not(billing_email: [nil, ""]).pluck(:billing_email)
  ```

**NOT in scope:**

- Changing any other Render env var, or touching production's service or Loops key.
- Removing pre-existing staging users (just record what's there; a stray real address
  is an issue-to-report, and a blocker only if it could receive mail).

**Build order:**

1. **Verify:** the three console reads print `:loops`, `true`, and the allowlist you
   just set (re-open the console after the restart — the old process has the old ENV).
2. **Record:** paste the allowlist value and the user/billing-email audit output into a
   scratch note for Task 14.

### Task 2 [Master]: Confirm Stripe test keys and the staging webhook endpoint

**Skills:** none
**Reference:** Design §Phase 0.4–0.5; `config/routes/` (`webhooks_stripe POST /webhooks/stripe`).

**In scope:**

- In the staging console:
  ```ruby
  Rails.application.credentials.dig(:stripe, :private_key).first(7)    # => "sk_test"
  Rails.application.credentials.dig(:stripe, :signing_secret).first(8)
  ```
- In the Stripe dashboard, **test mode** → Developers → Webhooks: confirm an endpoint
  at `https://staging.covehomeschool.com/webhooks/stripe` with at least these events
  enabled: `charge.succeeded`, `charge.refunded`, `invoice.payment_failed`,
  `invoice.payment_action_required`, `customer.subscription.updated`,
  `customer.subscription.deleted`.
- Reveal its signing secret; confirm the first 8 characters match what the console
  printed. **A mismatch means every webhook is silently rejected before Pay sees it** —
  stop and resolve before continuing.
- If the endpoint does not exist, create it with those events (this resolves the
  design's Open Question 2).

**NOT in scope:**

- Touching any live-mode Stripe object or webhook endpoint.
- Rotating credentials.

**Build order:**

1. **Verify:** `sk_test` prefix confirmed, and endpoint signing secret matches the
   credential's first 8 chars.
2. **Record:** whether the endpoint pre-existed or you created it — that answers Open
   Question 2 in the design doc.

### Task 3 [Master]: Create the Stripe test product/price and the matching Plan

**Skills:** none
**Reference:** Design §Phase 0.6–0.7. `db/seeds.rb` only creates
`Plan(fake_processor_id: "cove_dev")`, which never touches Stripe — hence a real
Stripe-backed plan is required to generate any charge or webhook.

**In scope:**

- Stripe dashboard, test mode: create a product with a recurring **yearly** price. Copy
  the `price_…` id.
- In the staging console:
  ```ruby
  Plan.create!(
    name: "COV-47 Verification (Yearly)",
    amount: 9900,
    currency: "usd",
    interval: "year",
    trial_period_days: 0,
    hidden: false,
    stripe_id: "price_..."
  )
  ```
- `trial_period_days: 0` is required — a trial makes the first invoice $0, so there'd be
  no `charge.succeeded` and no receipt. `hidden: false` is required for it to show on
  the pricing page.

**NOT in scope:**

- Editing or hiding any existing `Plan` row.
- Creating more than one plan.

**Build order:**

1. **Verify:** the plan appears on staging's pricing page, and
   `Plan.find_by(name: "COV-47 Verification (Yearly)").stripe_id` matches the Stripe
   price id.

> **Checkpoint 1 (Tasks 1–3):** run `/review-changes-mini` covering Tasks 1–3. There are
> no code changes here, so this checks that the working tree contains no unintended
> edits and that the Phase 0 outcomes (allowlist value, webhook endpoint status, plan
> id) are captured for Task 14. If Tasks 1–3 were run as a parallel batch, the master
> runs this once after the whole batch returns — exactly once per checkpoint either way.

### Task 4 [Master]: Create the verification user and set the billing email

**Skills:** none
**Reference:** Design §Phase 0.8–0.9. `account_types` is `"personal"`
(`config/jumpstart.rb:9`), so signup auto-creates the personal account used throughout.

**In scope:**

- Sign up through the staging UI at `/users/sign_up` with `<you>@gmail.com`. Record the
  password — Task 8 changes it.
- In the staging UI, Billing → billing email field → `<you>+cov47billing@gmail.com`.
- Confirm:
  ```ruby
  Account.find_by(owner: User.find_by(email: "<you>@gmail.com")).billing_email
  ```

**NOT in scope:**

- Creating a team account (there is no team path under `personal` account types).
- Any subscription yet.

**Build order:**

1. **Verify:** the console read returns `<you>+cov47billing@gmail.com`, and you can sign
   in to staging as the new user.

### Task 5 [Master]: Subscribe, cancel, refund — emails 5 and 6

**Skills:** none
**Reference:** Design §Phase 1. `Pay.mail_to` (`config/initializers/pay.rb:9-17`)
returns up to two recipients, so billing mail fans out to both addresses via two
separate Loops requests.

**In scope:**

- **5.1** At `/billing/new`, subscribe to the COV-47 plan with card
  `4242 4242 4242 4242`, any future expiry/CVC. Produces `charge.succeeded`.
  - → **Email 5 `receipt`** (Tier A). Expect it at **both** addresses — this satisfies
    the fan-out criterion. Open the attached PDF and confirm it renders.
  - Note the wall-clock time of the charge; Task 11's replay must be within 24h of it.
    Note the Stripe event id of the `charge.succeeded`.
- **5.2** Immediately cancel at Billing → Cancel subscription. **Note the wall-clock
  time** — this schedules `cancellation_reason` with `deliver_later(wait: 1.hour)`
  (`lib/jumpstart/app/controllers/billing/subscriptions/cancels_controller.rb:25`),
  collected in Task 10. Cancelling at period end does not refund, so 5.3 still works.
- **5.3** Stripe dashboard → Payments → the charge → Refund (full). Produces
  `charge.refunded`.
  - → **Email 6 `refund`** (Tier A). Also expect it at both addresses.
- Check `manage_subscription_url` in these emails opens staging billing.

**NOT in scope:**

- Filling in the results table yet (Task 14 does that in one pass) — but do record
  timestamps, placement (Inbox/Promotions/Spam), and Stripe event ids as you go.
- Fixing anything that renders wrong.

**Build order:**

1. **Verify:** both emails present in both inboxes; receipt PDF opens; times and event
   ids recorded.

### Task 6 [Master]: The two failure-path billing emails — 7 and 8

**Skills:** none
**Reference:** Design §Phase 2.

**In scope:**

- **6.1** Subscribe again with card `4000 0000 0000 0341` (attaches, then the charge
  fails) → `invoice.payment_failed`.
  - → **Email 7 `payment_failed`** (Tier A). Confirm `update_billing_url` opens
    staging's billing page.
- **6.2** Subscribe again with card `4000 0025 0000 3155` (requires 3-D Secure) and
  **abandon** the authentication prompt → `invoice.payment_action_required`.
  - → **Email 8 `payment_action_required`** (Tier A). Open `confirm_payment_url` from
    the email and confirm it reaches Stripe's confirmation page — a named acceptance
    criterion.

**NOT in scope:**

- Completing the 3DS authentication (that would produce a successful charge instead).
- Deleting the failed subscriptions yet — Task 7 needs `customer.subscriptions.last` to
  exist; clean them up in Task 15.

**Build order:**

1. **Verify:** both emails received; both URLs open the pages described; placement
   recorded.

### Task 7 [Master]: The three clock-dependent billing emails (Tier B) — 9, 10, 11

**Skills:** none
**Reference:** Design §Phase 3 and "Why three billing emails are Tier B". These use
`deliver_now` deliberately: a console `deliver_later` runs in the console process's
`:async` pool and dies with the console.

**In scope:**

- In the staging console:
  ```ruby
  user     = User.find_by(email: "<you>@gmail.com")
  account  = user.accounts.first
  customer = account.payment_processor
  sub      = customer.subscriptions.last
  ```
- **7.1** `subscription_renewing`:
  ```ruby
  Pay::UserMailer.with(pay_customer: customer, pay_subscription: sub, date: 1.year.from_now)
    .subscription_renewing.deliver_now
  ```
- **7.2/7.3** the trial pair — both call `.iso8601` on `trial_ends_at`, so it must not be
  nil; set it, send, restore:
  ```ruby
  original = sub.trial_ends_at

  sub.update_columns(trial_ends_at: 3.days.from_now)
  Pay::UserMailer.with(pay_customer: customer, pay_subscription: sub)
    .subscription_trial_will_end.deliver_now

  sub.update_columns(trial_ends_at: 1.day.ago)
  Pay::UserMailer.with(pay_customer: customer, pay_subscription: sub)
    .subscription_trial_ended.deliver_now

  sub.update_columns(trial_ends_at: original)
  ```

**NOT in scope:**

- Building a Stripe test clock or hand-inserting `Pay::Customer`/`Pay::Subscription`
  rows to force a genuine webhook — the design explicitly rejects that as re-proving
  already-unit-tested wiring.
- Leaving `trial_ends_at` modified: the restore line is mandatory.

**Build order:**

1. **Verify:** three emails received; `sub.reload.trial_ends_at == original` after the
   restore.

> **Checkpoint 2 (Tasks 4–7):** run `/review-changes-mini` covering Tasks 4–7 once all
> four are done — confirms no stray code edits and that the eight billing/receipt data
> points (times, placements, event ids, PDF result) are captured. Runs exactly once for
> the checkpoint.

### Task 8 [Master]: The two Devise emails — 1 and 2

**Skills:** none
**Reference:** Design §Phase 4. `reset_password_url` is hand-built into `dataVariables`
by COV-43 because the ERB view no longer renders — a wrong URL here would be invisible
until a real user hit it, which is why the click-through is a named AC.

**In scope:**

- **8.1** Request a password reset at `/users/password/new` for `<you>@gmail.com`.
  - → **Email 1 `reset_password_instructions`** (Tier A).
- **8.2** Open `reset_password_url` from the received email, set a new password, and
  confirm you can sign in with it. Record the new password.
  - Completing the reset also fires the change notification
    (`send_password_change_notification = true`, `config/initializers/devise.rb:154`).
  - → **Email 2 `password_change`** (Tier A).

**NOT in scope:**

- Reconstructing the reset URL by hand — the whole point is to click the one in the
  email.

**Build order:**

1. **Verify:** both emails received; the reset link loads the form; the password
   actually changes (sign in with the new one).

### Task 9 [Master]: The invitation — email 3

**Skills:** none
**Reference:** Design §Phase 5. Do **not** use madmin: its create action calls `save`,
while the mail is sent by `AccountInvitation#save_and_send_invite`
(`lib/jumpstart/app/models/account_invitation.rb:14-17`) — there's no `after_create`
callback, so madmin sends nothing.

**In scope:**

- In the staging console:
  ```ruby
  user    = User.find_by(email: "<you>@gmail.com")
  account = user.accounts.first

  AccountInvitation.new(
    account: account,
    email: "<you>@gmail.com",
    name: "COV-47 Invite Check",
    invited_by: user
  ).save_and_send_invite
  ```
  - → **Email 3 `invite`** (Tier A — the real trigger method; only its entry point
    differs from a UI click that doesn't exist under `personal` account types).
- Open `invitation_url` from the email and confirm the invitation page loads — a named
  AC.

**NOT in scope:**

- Accepting the invitation (not required by any AC, and it would mutate the verification
  account's membership).
- Enabling team account types to get a UI path.

**Build order:**

1. **Verify:** email received; `invitation_url` loads the invitation page.

> **Checkpoint 3 (Tasks 8–9):** run `/review-changes-mini` covering Tasks 8–9 after both
> are done.

### Task 10 [Master]: The cancellation survey — email 4

**Skills:** none
**Reference:** Design §Phase 6. Staging runs `:async`
(`config/environments/staging.rb:57`), not `:inline` — COV-46 changed this because
`:inline` raises `NotImplementedError` on `enqueue_at`. So the one-hour delay is real,
**and an `:async` job does not survive a service restart.**

**In scope:**

- Roughly one hour after Task 5.2's cancel, check the inbox.
  - → **Email 4 `cancellation_reason`** (Tier A).
- If staging restarted in the interim the job was lost. Fall back to a console send and
  **record the row as Tier B with a note** — do not record it as Tier A:
  ```ruby
  user = User.find_by(email: "<you>@gmail.com")
  sub  = user.accounts.first.payment_processor.subscriptions.last
  AccountMailer.with(subscription: sub, user: user).cancellation_reason.deliver_now
  ```

**NOT in scope:**

- Restarting or redeploying staging during the waiting hour (it would destroy the queued
  job).

**Build order:**

1. **Verify:** email received; tier recorded honestly (A if it arrived on the timer, B
   with a note if you had to fall back).

### Task 11 [Master]: Webhook replay — the idempotency check

**Skills:** none
**Reference:** Design §Phase 7 and §Corrections item 3. `LoopsClient#send_transactional`
rescues `Conflict` and returns true (`app/clients/loops_client.rb:100-102`), so the
correct result is **zero** additional emails, not one.

**In scope:**

- Stripe dashboard → Developers → Events → the original `charge.succeeded` from Task 5.1
  → **Resend** to the staging endpoint. **Must be within 24h of the original.**
- In Render staging **Logs**, search for
  `[Loops] duplicate transactional send suppressed`.
- Record which of the three outcomes occurred:
  - **Line present** → Loops' idempotency key caught the duplicate. This is what the AC
    wants.
  - **Line absent, no new email** → Pay deduped the webhook before `LoopsDelivery` ran.
    Record honestly: the Loops idempotency layer was **not** exercised and the AC is only
    partially met.
  - **A second email arrives** → genuine failure. Record it and open a follow-up ticket.

**NOT in scope:**

- Forging a webhook by hand to force the path if Pay dedupes it — record the partial
  result instead.

**Build order:**

1. **Verify:** inbox shows zero new emails; the log search outcome is recorded verbatim.

### Task 12 [Master]: Forced Loops failure — the Honeybadger check

**Skills:** none
**Reference:** Design §Failure injection. Use a bogus `transactionalId`, **not** a
revoked API key — revocation is account-level, risks hitting production's sibling key,
and is easy to forget to restore. `LoopsMailDeliveryJob` deliberately omits `BadRequest`
from `retry_on`, so the job fails on the first attempt.

**In scope:**

- In the staging console (inline mailer class resolves because `:async` runs the job in
  this same process):
  ```ruby
  class Cov47FailureMailer < ApplicationMailer
    def boom
      mail(
        to: params[:to],
        "X-Loops-Transactional-Id": "cov47_deliberately_invalid_id",
        "X-Loops-Data-Variables": "{}",
        body: ""
      )
    end
  end

  Cov47FailureMailer.with(to: "<you>@gmail.com").boom.deliver_later
  sleep 15
  ```
- Keep the console open through the sleep. This **must** go through `deliver_later` — a
  `deliver_now` raises in the console and may never reach Honeybadger, proving nothing.
- In Honeybadger: confirm a new `LoopsClient::BadRequest` with a stack trace running
  through `LoopsDelivery` and `LoopsMailDeliveryJob`, and confirm **exactly one
  occurrence** (it must not be retried).
- Record the Honeybadger fault URL.

**NOT in scope:**

- Revoking or rotating any Loops API key.
- Committing `Cov47FailureMailer` anywhere — it exists only in the console session.

**Build order:**

1. **Verify:** fault visible in Honeybadger with a usable stack trace, occurrence count
   is 1, fault URL recorded.

> **Checkpoint 4 (Tasks 10–12):** run `/review-changes-mini` covering Tasks 10–12 after
> all three are done.

### Task 13 [Master]: Loops dashboard audit and message ids

**Skills:** none
**Reference:** Design §Phase 9. `addToAudience: false` is hard-coded in
`LoopsClient#send_transactional` (`app/clients/loops_client.rb:88-94`) and staging has
`contact_sync_enabled: false` (`config/loops.yml`), so both contact-creating paths
should be closed. A contact appearing here is a non-consenting one — which matters more
now that COV-51's marketing sync is live.

**In scope:**

- In the Loops dashboard, check **Contacts**, **Audiences**, and **Mailing Lists**: none
  of the eleven sends may have created anything. Record each as pass/fail.
- From the Loops transactional log, collect the **message id for each of the eleven
  sends** — that's the per-row identifier the AC requires.

**NOT in scope:**

- Deleting anything found in Loops (record it and open a ticket; deletion is a separate
  decision).

**Build order:**

1. **Verify:** three audit answers recorded; eleven message ids collected.

### Task 14 [Master]: Fill in the results tables and log issues

**Skills:** none
**Reference:** Design §Results, §Link checks, §Behaviour checks, §Issues found.

**In scope:**

- Edit `docs/designs/cov-47-loops-verification.md` only:
  - **Results table**: all eleven rows — tier, trigger, sent at, received at, placement,
    Loops message id, notes. Correct the tier for row 4 if Task 10 fell back to console.
  - **Link checks table**: all six rows.
  - **Behaviour checks table**: all eight rows, including the Honeybadger fault URL.
  - **Issues found**: one line per problem discovered, each with its follow-up ticket
    identifier.
  - Update Open Question 2 with whether the Stripe webhook endpoint pre-existed (from
    Task 2).
- Open a Linear follow-up ticket for each issue found. Spam placement is recorded and
  **does not block** — but a genuinely misconfigured template is not excused as "the
  domain will warm up."

**NOT in scope:**

- Any code change, in this repo or elsewhere, to fix what was found.
- Leaving a table cell blank — if something wasn't checked, write why.

**Build order:**

1. **Implement:** fill in the three tables and Issues found in the design doc.
2. **Verify:** no empty cells remain; every recorded failure has a ticket identifier next
   to it.

### Task 15 [Master]: Staging cleanup

**Skills:** none
**Reference:** Design §Phase 10.

**In scope:**

- In the staging console:
  ```ruby
  Plan.find_by(name: "COV-47 Verification (Yearly)").destroy
  AccountInvitation.where(email: "<you>@gmail.com").destroy_all
  ```
- Archive the Stripe test product so it stops appearing on future pricing pages.
- Decide and record: keep or remove the verification user and its subscriptions (keeping
  them is fine and useful for future verification).

**NOT in scope:**

- Removing the two addresses from `STAGING_EMAIL_RECIPIENT_ALLOWLIST` — COV-46 made the
  allowlist the standing safety mechanism, not a temporary one. Only clear it if you
  specifically want staging to go quiet.
- Deleting the Stripe webhook endpoint.

**Build order:**

1. **Verify:** `Plan.find_by(name: "COV-47 Verification (Yearly)")` returns nil; Stripe
   product shows as archived; pricing page no longer lists the plan.

> **Checkpoint 5 (Tasks 13–15):** run `/review-changes-mini` covering Tasks 13–15 — this
> is the one checkpoint with a real diff (the design doc). Confirm the doc is the only
> changed file and every table is complete. Then `/close-out`.

## Task Dependencies

- Tasks 1 → 2 → 3 are sequential (allowlist restart must settle before console reads;
  the plan needs the verified Stripe keys).
- Task 4 depends on Task 3 (needs the plan on the pricing page).
- Task 5 depends on Task 4. Task 6 depends on Task 5's flow being understood but uses
  fresh subscriptions.
- Task 7 depends on Tasks 5–6 (needs `customer.subscriptions.last` to exist).
- **Tasks 8 and 9 are independent of 5–7** and can be done in any order — they exist
  partly to fill the one-hour cancellation window opened by Task 5.2.
- Task 10 is a hard wall clock: ~1 hour after Task 5.2, and no staging restart in
  between.
- Task 11 must land within 24 hours of Task 5.1.
- Task 12 is independent of everything except Task 1.
- Task 13 comes after all eleven sends (Tasks 5–10).
- Task 14 depends on Tasks 5–13. Task 15 comes last.
- Nothing here parallelises across people usefully — it's one operator, one inbox, one
  staging service.

## Operator Notes

- **Task 8 changes the verification user's password.** If you re-enter the billing UI
  afterwards, use the new one. Devise is ordered after billing partly for this reason.
- **Task 10's one-hour window is fragile.** Any Render redeploy during it (including one
  triggered by an unrelated merge to `main` with `autoDeploy: true`) silently kills the
  queued job and downgrades row 4 to Tier B. Consider pausing auto-deploy, or just accept
  the fallback.
