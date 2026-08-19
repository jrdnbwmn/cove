> Plan created: docs/plans/cov-47-loops-verification.md
> Ticket: COV-47
> Branch: feature/cov-47-e2e-transactional-email-verification

# Feature: End-to-end verification of all eleven transactional emails

## Problem

Every ticket in the transactional track (COV-39, COV-40 through COV-45) proves a
payload is shaped correctly or a template renders in Loops' preview. None proves
an email arrives. `POST /v1/transactional` returning 200 means Loops accepted the
request — unverified sending domains, unpublished templates, spam filtering, and
per-recipient failures all produce a 200 and no email in anyone's inbox.

Two behaviours are also unproven end to end: that a Loops failure surfaces in
Honeybadger rather than being swallowed, and that the content-derived idempotency
keys actually stop a replayed Stripe webhook from double-sending.

## Approach

Trigger one real send per email type against **staging**, which COV-46 made live
behind a fail-closed exact-address recipient allowlist, and confirm receipt in a
real Gmail inbox each time. Record every result in the table at the bottom of
this document.

This ticket makes **no code changes**. Anything the verification breaks becomes a
follow-up ticket, not a fix on this branch.

### Fidelity ladder

Not every send can be driven by a genuine Stripe webhook, and pretending
otherwise would produce a doc that overclaims. Each row in the results table is
labelled with its fidelity tier:

- **Tier A — genuine trigger.** The real production code path fires: a UI action
  or a real Stripe webhook reaches the real mailer, which reaches Loops.
- **Tier B — mailer invoked directly** from the staging console against real
  `Pay` records. Proves the payload, the Loops template, the delivery method, and
  inbox arrival. Does *not* re-prove the webhook→mailer wiring, which COV-45
  already covers with unit tests.

Nine of the eleven are Tier A. The three clock-dependent billing emails are Tier
B — see "Why three billing emails are Tier B" below.

### Why three billing emails are Tier B

The ticket proposed driving all seven billing emails with `stripe trigger`. That
does not work: `stripe trigger` fabricates a brand-new Stripe customer, which has
no matching `Pay::Customer` row in the staging database, so Pay's webhook
handlers find nothing and return without sending. Genuine webhook sends require
real subscriptions created through the staging UI.

Four of the seven are reachable that way, each by subscribing with a specific
test card. The remaining three — `subscription_renewing`,
`subscription_trial_will_end`, `subscription_trial_ended` — depend on Stripe's
clock. Stripe test clocks can only be attached to a customer at creation time,
and ours is created by checkout, so a genuine webhook for these would mean
hand-building a clocked customer in Stripe *and* hand-inserting matching
`Pay::Customer` / `Pay::Subscription` rows to match it. That is a large amount of
fabrication to re-prove a webhook branch that is already unit-tested. What is
genuinely unproven for these three is the Loops leg — payload, template, inbox —
and a direct mailer call proves exactly that.

### Corrections to the ticket's stated premises

Three things in COV-47's description no longer match what shipped:

1. **Staging is not `:inline`.** COV-46 set
   `config.active_job.queue_adapter = :async` (`config/environments/staging.rb:57`)
   because `:inline` raises `NotImplementedError` on `enqueue_at`, which
   `deliver_later(wait: 1.hour)` needs. So the cancellation survey's one-hour
   delay is real, and an `:async` job is lost if staging restarts.
2. **The receipt carries a PDF attachment, not a `receipt_url`.** COV-45 reversed
   COV-37's link-not-attachment decision after Loops enabled attachments for
   Cove. `app/mailers/pay/user_mailer.rb` raises if the PDF is missing. The
   acceptance criterion is read as "PDF attached."
3. **A replayed webhook produces zero additional emails, not one.**
   `LoopsClient#send_transactional` rescues `Conflict` and returns true
   (`app/clients/loops_client.rb:100-102`), so Loops' 24-hour idempotency window
   suppresses the duplicate silently. The AC means "one email total across the
   original and the replay."

### Failure injection

Force the failure with a bogus `transactionalId` rather than by revoking the
staging API key. Loops answers 400, `LoopsClient` raises
`LoopsClient::BadRequest`, and `LoopsMailDeliveryJob` deliberately does not list
that class in its `retry_on` (`app/jobs/loops_mail_delivery_job.rb`), so the job
fails on first attempt and Honeybadger's Active Job hook reports it with a real
stack trace. Revoking the key is account-level, affects production's sibling key
handling by mistake if the wrong one is picked, and is easy to forget to restore.

The injection must go through `deliver_later`. A console-level `deliver_now`
raises in the console and may never reach Honeybadger, which would prove nothing.

### Replay

Use the Stripe dashboard's **Resend** on the real `charge.succeeded` event, and
check the staging log for `[Loops] duplicate transactional send suppressed`. That
log line is what distinguishes "Loops idempotency caught it" from "Pay deduped
the webhook before we ever called Loops." Only the first proves what the AC is
after. The resend must happen within 24 hours of the original.

## Acceptance Criteria

- All eleven types received in the real inbox, one results-table row each with
  timestamp, fidelity tier, and Loops message id.
- `reset_password_url` from a real email opens the reset form and successfully
  changes a password.
- `invitation_url` from a real invite email opens the invitation.
- `confirm_payment_url` from a real `payment_action_required` email opens
  Stripe's confirmation page.
- The receipt email arrives with the Pay-generated PDF attached and the PDF
  opens.
- With `billing_email` set, both addresses receive the billing email.
- Replaying one Stripe webhook produces zero additional emails, and the staging
  log shows the Loops duplicate-suppressed line.
- A forced Loops failure appears in Honeybadger with a usable stack trace.
- No contact, audience, or mailing list appears in the Loops dashboard
  afterwards, confirming `addToAudience: false` held across all eleven.
- Spam placement is recorded per row and does not block the ticket.
- This document, with the table filled in, is merged.

## Prototype

None. This is operational verification with no Cove UI work.

## Data Model

No schema or model changes.

Temporary staging records created for the exercise, all removed in cleanup:

- One `Plan` row carrying a Stripe test-mode `stripe_id`. `db/seeds.rb` only
  creates `Plan(fake_processor_id: "cove_dev")`, and the fake processor never
  touches Stripe, so nothing in staging today can generate a charge or a webhook.
  Yearly, `trial_period_days: 0` — a trial would make the first invoice $0, so
  there would be no `charge.succeeded` and no receipt.
- One verification `User` whose email is the allowlisted address, plus that
  user's personal `Account` with `billing_email` set to the second address.
- Up to three `Pay::Subscription` records from the three checkout attempts.
- One `AccountInvitation`.

## Screens / Flows

The runbook. Steps are ordered so the one-hour cancellation timer matures while
the billing work happens.

Two shells are used throughout:

- **Render staging shell** — the Shell tab on the staging service.
- **Staging console** — `bin/rails console` inside that shell.

`deliver_later` from the console runs in that console process's `:async` thread
pool, so the console must stay open until the job runs. Tier B sends therefore
use `deliver_now`; only the Honeybadger injection uses `deliver_later`.

### Phase 0 — prerequisites (blocking)

**0.1 Confirm staging mail config.** In the staging console:

```ruby
Rails.application.config.action_mailer.delivery_method      # => :loops
Rails.application.config.action_mailer.perform_deliveries   # => true
ENV["STAGING_EMAIL_RECIPIENT_ALLOWLIST"]
```

**0.2 Add both addresses to the allowlist.** COV-46's guard is exact-match and
does not broaden plus-addresses, so both must be listed literally in Render's
`STAGING_EMAIL_RECIPIENT_ALLOWLIST`:

- `<you>@gmail.com` — the verification user's login address, and the recipient of
  every non-billing email.
- `<you>+cov47billing@gmail.com` — the account's `billing_email`, needed for the
  fan-out criterion. This is the one deviation from "one address": AC 6 requires
  two inboxes receiving the same billing email.

Changing the variable in Render restarts the service. Do this before anything
else, not mid-run.

**0.3 Audit existing staging users.** No real third-party address may be sitting
in the staging database:

```ruby
User.pluck(:email)
Account.where.not(billing_email: [nil, ""]).pluck(:billing_email)
```

**0.4 Confirm Stripe test keys in staging credentials:**

```ruby
Rails.application.credentials.dig(:stripe, :private_key).first(7)     # => "sk_test"
Rails.application.credentials.dig(:stripe, :signing_secret).first(8)
```

**0.5 Confirm the Stripe webhook endpoint exists.** In the Stripe dashboard, in
**test mode**: Developers → Webhooks. There must be an endpoint at
`https://staging.covehomeschool.com/webhooks/stripe` (route verified:
`webhooks_stripe POST /webhooks/stripe`) with at least these events enabled:

- `charge.succeeded`
- `charge.refunded`
- `invoice.payment_failed`
- `invoice.payment_action_required`
- `customer.subscription.updated`
- `customer.subscription.deleted`

Reveal its signing secret and confirm the first 8 characters match what 0.4
printed. A mismatch means every webhook is rejected before Pay sees it, silently.
If the endpoint does not exist, create it — that is a prerequisite, not a
surprise.

**0.6 Create the Stripe test-mode product and price.** In the Stripe dashboard,
test mode: a product with a recurring **yearly** price. Copy the price id
(`price_…`).

**0.7 Create the matching Plan in staging:**

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

`hidden: false` is required for it to appear on the pricing page. Cleanup removes
it.

**0.8 Create the verification user.** Sign up through the staging UI at
`/users/sign_up` with `<you>@gmail.com`. `account_types` is `"personal"`
(`config/jumpstart.rb:9`), so this creates a personal account automatically.

**0.9 Set the billing email.** In the staging UI, Billing → the billing email
field, set to `<you>+cov47billing@gmail.com`. Confirm:

```ruby
Account.find_by(owner: User.find_by(email: "<you>@gmail.com")).billing_email
```

### Phase 1 — subscribe and cancel (starts the one-hour clock)

**1.1 Subscribe with card `4242 4242 4242 4242`**, any future expiry, any CVC, at
`/billing/new` (pricing → the COV-47 plan). This produces `charge.succeeded`.

→ **Email 5, `receipt`** (Tier A). Expect it at **both** addresses — that is the
`Pay.mail_to` fan-out from `config/initializers/pay.rb:9-17`, and it satisfies AC
6. Confirm the PDF attachment opens.

**1.2 Cancel the subscription immediately** at Billing → Cancel subscription
(`/billing/subscriptions/:subscription_id/cancel`). This schedules
`cancellation_reason` with `deliver_later(wait: 1.hour)`
(`lib/jumpstart/app/controllers/billing/subscriptions/cancels_controller.rb:25`).
Note the wall-clock time; the email is expected roughly one hour later, in Phase
6. Cancelling at period end does not refund the charge, so 1.3 still works.

**1.3 Refund the charge** in the Stripe dashboard: Payments → the charge → Refund
(full). This produces `charge.refunded`.

→ **Email 6, `refund`** (Tier A). Also fans out to both addresses.

### Phase 2 — the two failure-path billing emails

**2.1 Subscribe again with card `4000 0000 0000 0341`** (attaches successfully,
then the charge fails). This produces `invoice.payment_failed`.

→ **Email 7, `payment_failed`** (Tier A). Check `update_billing_url` opens
staging's billing page.

**2.2 Subscribe again with card `4000 0025 0000 3155`** (requires 3-D Secure
authentication). Abandon the authentication prompt rather than completing it.
This produces `invoice.payment_action_required`.

→ **Email 8, `payment_action_required`** (Tier A). Open `confirm_payment_url`
from the email and confirm it reaches Stripe's confirmation page — that is a
named acceptance criterion.

Clean up the two failed subscriptions afterwards if they clutter the billing page;
they are not needed again.

### Phase 3 — the three clock-dependent billing emails (Tier B)

In the staging console. `pay_customer` is required by `Pay.mail_arguments`, which
is what resolves the recipients.

```ruby
user     = User.find_by(email: "<you>@gmail.com")
account  = user.accounts.first
customer = account.payment_processor
sub      = customer.subscriptions.last
```

**3.1 `subscription_renewing`:**

```ruby
Pay::UserMailer.with(
  pay_customer: customer,
  pay_subscription: sub,
  date: 1.year.from_now
).subscription_renewing.deliver_now
```

→ **Email 9** (Tier B). Note: on the webhook path this fires from
`invoice.upcoming` and Pay gates it to yearly plans only
(`Pay.emails.subscription_renewing`); the direct call bypasses that gate, which is
fine because the plan is yearly anyway.

**3.2 and 3.3 — the trial pair.** Both read `subscription.trial_ends_at` and call
`.iso8601` on it, so it must not be nil. Set it, send, then restore:

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

→ **Emails 10 and 11** (Tier B).

### Phase 4 — the two Devise emails

**4.1 Request a password reset** at `/users/password/new` for
`<you>@gmail.com`.

→ **Email 1, `reset_password_instructions`** (Tier A).

**4.2 Open `reset_password_url` from that email** and set a new password. This is
a named acceptance criterion — the URL is hand-built into `dataVariables` by
COV-43 because the ERB view that used to generate it no longer renders, so a
wrong URL here would be invisible until a real user hit it.

Completing the reset also fires the second email, because
`send_password_change_notification = true` (`config/initializers/devise.rb:154`).

→ **Email 2, `password_change`** (Tier A).

### Phase 5 — the invite

The invitation UI is unavailable: `account_types` is `"personal"`
(`config/jumpstart.rb:9`), so there are no team accounts to invite into.

The ticket suggests madmin. **That will not send the email.** madmin's create
action calls `save`, while the mail is sent by
`AccountInvitation#save_and_send_invite`
(`lib/jumpstart/app/models/account_invitation.rb:14-17`) — there is no
`after_create` callback. Use the console instead:

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

→ **Email 3, `invite`** (Tier A — this is the real trigger method; only its entry
point differs from a UI click that does not exist).

Open `invitation_url` from the email and confirm it loads the invitation page.
That is a named acceptance criterion.

### Phase 6 — the cancellation survey

Roughly one hour after step 1.2.

→ **Email 4, `cancellation_reason`** (Tier A).

If staging restarted in the interim, the `:async` job was lost — jobs do not
survive a restart under that adapter. Fall back to a console send and record the
row as Tier B with a note:

```ruby
user = User.find_by(email: "<you>@gmail.com")
sub  = user.accounts.first.payment_processor.subscriptions.last

AccountMailer.with(subscription: sub, user: user).cancellation_reason.deliver_now
```

### Phase 7 — the idempotency replay

In the Stripe dashboard: Developers → Events → the original `charge.succeeded`
from step 1.1 → **Resend** to the staging endpoint. Must be within 24 hours of the
original, or Loops' idempotency window has expired and the test proves nothing.

Then, in the Render staging **logs**, search for:

```
[Loops] duplicate transactional send suppressed
```

- Line present → Loops' idempotency key caught the duplicate. This is the result
  the AC wants.
- Line absent and no new email → Pay deduped the webhook before `LoopsDelivery`
  ran. Record this honestly; it means the Loops idempotency layer was not
  exercised, and the AC is only partially met.
- A second email arrives → genuine failure. Record it and open a ticket.

Expected inbox result either way: **zero** new emails.

### Phase 8 — the forced Loops failure

In the staging console. Defining the mailer inline works because `:async` runs
the job in this same process, so the constant resolves when the job deserialises:

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

Keep the console open for the sleep. Then confirm in Honeybadger: a new
`LoopsClient::BadRequest` with a stack trace running through `LoopsDelivery` and
`LoopsMailDeliveryJob`. Confirm there is exactly one occurrence — that class is
absent from `retry_on`, so it must not be retried.

Record the Honeybadger fault URL in the results table.

### Phase 9 — the Loops audit

In the Loops dashboard, immediately after: **Contacts**, **Audiences**, and
**Mailing Lists**. None of the eleven sends may have created anything.
`addToAudience: false` is hard-coded in `LoopsClient#send_transactional`
(`app/clients/loops_client.rb:88-94`), and staging has
`contact_sync_enabled: false` (`config/loops.yml`), so both contact-creating paths
should be closed. A contact appearing here would be a non-consenting one, which
matters more now that COV-51's marketing sync is live.

Also record each send's message id from the Loops dashboard's transactional log
as you go — that is the per-row identifier the AC asks for.

### Phase 10 — cleanup

```ruby
Plan.find_by(name: "COV-47 Verification (Yearly)").destroy
AccountInvitation.where(email: "<you>@gmail.com").destroy_all
```

Leave the verification user and its subscriptions in place if useful for future
verification; otherwise remove them. Remove the two addresses from
`STAGING_EMAIL_RECIPIENT_ALLOWLIST` only if staging should go quiet again — COV-46
made the allowlist the standing safety mechanism, not a temporary one.

**2026-08-19 cleanup decision:** retain the staging verification user, but remove
its COV-47 subscriptions and test customers. The bridge cleanup removed one local
plan, invitation, subscription, charge, payment method, and customer. The six
clearly named COV-47 Stripe sandbox customers were then deleted; archiving the
Stripe test product completed afterward.

Archive the Stripe test product so it does not appear in future pricing pages.

## Results

Fill in as each send lands. Placement is `Inbox`, `Promotions`, or `Spam`.

| # | Email | Tier | Trigger | Sent at | Received at | Placement | Loops message id | Notes |
| -- | -- | -- | -- | -- | -- | -- | -- | -- |
| 1 | `reset_password_instructions` | A | UI: forgot password | 2026-08-19 | Received | Not recorded | Unavailable | Loops Metrics exposes recipient and sent/delivered timestamps, but no per-send message ID. Reset link opened the form and completed a password change. |
| 2 | `password_change` | A | UI: complete reset | 2026-08-19 | Received | Not recorded | Unavailable | Loops Metrics exposes no per-send message ID. Received after the password reset completed. |
| 3 | `invite` | A | Staging verification bridge | 2026-08-19 | Received | Not recorded | Unavailable | Loops Metrics exposes no per-send message ID. Invitation email and link verified; invitation was not accepted. |
| 4 | `cancellation_reason` | A | UI: cancel, +1h | 2026-08-05 | Received | Not recorded | Unavailable | Loops Metrics exposes no per-send message ID. Received after the scheduled one-hour delay; Plain template intentionally has no theme styling. |
| 5 | `receipt` | A | Stripe `charge.succeeded` | 2026-08-05; replay check 2026-08-19 20:32 UTC | Received | Not recorded | Unavailable | Loops Metrics exposes no per-send message ID. Received at both controlled addresses; PDF attachment opened successfully. Fresh successful charge on 2026-08-19 received one receipt; replay produced no second receipt. |
| 6 | `refund` | A | Stripe `charge.refunded` | 2026-08-05 | Received | Not recorded | Unavailable | Loops Metrics exposes no per-send message ID. Refund email received. |
| 7 | `payment_failed` | A | Stripe `invoice.payment_failed` | 2026-08-06 16:58 (Stripe dashboard) | Received | Not recorded | Unavailable | Loops Metrics exposes no per-send message ID. Both controlled inboxes received it; webhook delivery returned HTTP 200; `update_billing_url` opens staging billing; received again in the fresh 2026-08-19 simulation after Loops repaired its sending-domain state. |
| 8 | `payment_action_required` | A | Stripe `invoice.payment_action_required` | 2026-08-19 (Stripe test-clock simulation) | Received | Not recorded | Unavailable | Loops Metrics exposes no per-send message ID. Fresh simulation after Loops repair; `confirm_payment_url` verified. |
| 9 | `subscription_renewing` | B | Staging verification bridge | 2026-08-19 | Received | Not recorded | Unavailable | Loops Metrics exposes no per-send message ID. "Your upcoming subscription renewal" received. |
| 10 | `subscription_trial_will_end` | B | Stripe test-clock simulation | 2026-08-19 (Stripe test-clock simulation) | Received | Not recorded | Unavailable | Loops Metrics exposes no per-send message ID. Generated incidentally by the one-day disposable verification trial; Cove's paid plan remains trial-free. |
| 11 | `subscription_trial_ended` | B | Staging verification bridge | 2026-08-19 | Received | Not recorded | Unavailable | Loops Metrics exposes no per-send message ID. Trial-ended email received. |

### Link checks

| Check | Result |
| -- | -- |
| `reset_password_url` opens the form and changes a password | Pass — 2026-08-19 |
| `invitation_url` opens the invitation | Pass — Email 3, 2026-08-19 |
| `confirm_payment_url` opens Stripe's confirmation page | Pass — Email 8, 2026-08-19 |
| Receipt PDF attached and opens | Pass — Email 5, 2026-08-05 |
| `update_billing_url` opens staging billing | Pass — Emails 7, 2026-08-06 and 2026-08-19 |
| `manage_subscription_url` opens staging billing | Pass — Email 9, 2026-08-19 |

### Behaviour checks

| Check | Result |
| -- | -- |
| Both addresses received the receipt (fan-out) | Pass — Email 5, 2026-08-05 |
| Webhook replay produced zero additional emails | Pass — `charge.succeeded` replay, 2026-08-19 |
| Staging log shows `[Loops] duplicate transactional send suppressed` | Pass — 2026-08-19 20:32:36 UTC (`cmsdrk6tf03rb0jzw194l0rl5`) |
| Honeybadger fault raised, with stack trace (fault URL) | Pass — `LoopsClient::NotFound`, 2026-08-19 14:33 MDT; deliberate nonexistent transactional ID returned "No transactional email found with that ID." |
| Honeybadger fault occurred exactly once (not retried) | Pass — one occurrence in Honeybadger History at 2026-08-19 14:33 MDT |
| Loops dashboard: no new contacts | Pass — 2026-08-19 |
| Loops dashboard: no new audiences | Pass — 2026-08-19 |
| Loops dashboard: no new mailing lists | Pass — 2026-08-19 |

### Issues found

Anything broken gets a line here and a follow-up ticket. Nothing is fixed on this
branch.

- 2026-08-12: The first Email 8 simulation used card `4000 0025 0000 3155` added
  through the Stripe Dashboard. Stripe completed a setup flow and the simulated
  renewal succeeded (`invoice.paid` / `payment_intent.succeeded`), so it did not
  produce `invoice.payment_action_required` or verify Email 8. Retry with Stripe's
  always-authenticate subscription/invoice test card (`4000 0027 6000 3184`).

## Scope

**In:** eleven real sends verified by inbox receipt and recorded in the table
above; the link checks; the `billing_email` fan-out check; the webhook replay;
the forced Honeybadger failure; the Loops dashboard audit; this document.

**Deferred:** production cutover; deliverability tuning; DMARC tightening beyond
`p=none`; inbox placement testing across providers; marketing verification
(COV-52, COV-55, COV-56); any code fix arising from what this finds.

## Open Questions

1. **If a type lands in spam, is that a blocker?** Resolved per the ticket's own
   recommendation: record it, do not block, open a deliverability ticket. The
   sending domain is cold and placement improves with volume — but a genuinely
   misconfigured template must not be excused as "it'll warm up."
2. **Whether the Stripe test-mode webhook endpoint already exists** (step 0.5).
   Resolved during verification: the dedicated staging endpoint was created and
   later retained as the standing test-mode webhook destination.

## More Info

- **`account_types` is `"personal"`** (`config/jumpstart.rb:9`), which is why the
  invite has no UI path, and why signup auto-creates the account used throughout.
- **`Pay.mail_to`** (`config/initializers/pay.rb:9-17`) returns an array of up to
  two recipients — account owner plus `billing_email`. `LoopsDelivery` issues one
  API call per recipient with a distinct idempotency key
  (`app/mailers/loops_delivery.rb:33-41`), so the fan-out check exercises two
  separate Loops requests, not one.
- **Idempotency keys are content-derived**: SHA256 over
  `[transactionalId, email, seed-or-variables]`
  (`app/clients/loops_client.rb:106-112`). Billing mailers pass an explicit seed
  built from the Stripe object id, which is why a webhook replay collides and a
  legitimately distinct second charge does not.
- **`LoopsMailDeliveryJob`** retries only `RateLimit`, `InternalError`,
  `Net::OpenTimeout`, and `Net::ReadTimeout`. `BadRequest`, `Conflict`,
  `PayloadTooLarge`, and the staging guard's blocked-recipient error all fail
  immediately by design.
- **Staging and production share one Loops team** (COV-38) with separate API keys.
  These sends consume the shared rate limit (10 req/s) and the shared domain
  reputation. Eleven sends is negligible, but that is why COV-46 kept staging
  delivery deliberately small.
- **The staging recipient guard covers ActionMailer only.** Direct `LoopsClient`
  calls bypass it — relevant only if something in Phase 9 suggests a contact was
  created outside the mail path.
