> Ticket: COV-37
> Branch: feature/cov-37-loops-interception-architecture-and-transport

# Decision brief: Loops interception architecture and transport

## Problem

Loops is not an ActionMailer delivery provider. The Jumpstart provider `case`
at `config/environments/production.rb:92` covers mailpace/mailgun/postmark/resend
and falls through to `else` → `Jumpstart.config.smtp_settings` at line 110.
`MAIL_PROVIDERS` in `lib/jumpstart/lib/jumpstart/configuration.rb:60-69` lists
seven names, none of them Loops.

Loops sends by referencing a template authored and published inside Loops
(`transactionalId`) plus a `dataVariables` hash. The email body — and the
subject — stop living in this repo. Eleven transactional triggers exist. This
brief resolves the three decisions that shape COV-39, COV-43, COV-44, COV-45,
and COV-46.

**No code, gems, credentials, templates, or config changes are made by this
ticket.** Everything below is a decision, not an implementation.

---

## The eleven triggers

| # | Trigger | Source | Delivery |
| -- | -- | -- | -- |
| 1 | `reset_password_instructions` | Devise `:recoverable`, enabled in `lib/jumpstart/app/models/user/authenticatable.rb:7` | via `send_devise_notification` |
| 2 | `password_change` | `config/initializers/devise.rb:154` sets `send_password_change_notification = true` (Devise default is `false`) | via `send_devise_notification` |
| 3 | `AccountMailer#invite` | `lib/jumpstart/app/models/account_invitation.rb:16` | `deliver_later` |
| 4 | `AccountMailer#cancellation_reason` | `lib/jumpstart/app/controllers/billing/subscriptions/cancels_controller.rb:25` | `deliver_later(wait: 1.hour)` |
| 5 | `Pay::UserMailer#receipt` | `pay-11.6.2/lib/pay/stripe/webhooks/charge_succeeded.rb:9` | `deliver_later` |
| 6 | `Pay::UserMailer#refund` | `pay-11.6.2/lib/pay/stripe/webhooks/charge_refunded.rb:9` | `deliver_later` |
| 7 | `Pay::UserMailer#payment_failed` | `pay-11.6.2/lib/pay/stripe/webhooks/payment_failed.rb:17` | `deliver_later` |
| 8 | `Pay::UserMailer#payment_action_required` | `pay-11.6.2/lib/pay/stripe/webhooks/payment_action_required.rb:19` | `deliver_later` |
| 9 | `Pay::UserMailer#subscription_renewing` | `pay-11.6.2/lib/pay/stripe/webhooks/subscription_renewing.rb:23` | `deliver_later` |
| 10 | `Pay::UserMailer#subscription_trial_will_end` | `pay-11.6.2/lib/pay/stripe/webhooks/subscription_trial_will_end.rb:13` | `deliver_later` |
| 11 | `Pay::UserMailer#subscription_trial_ended` | `pay-11.6.2/lib/pay/stripe/webhooks/subscription_trial_will_end.rb:18` (same handler, `elsif` branch) | `deliver_later` |

**Not triggers.** No `:confirmable` and no `:lockable` on `User::Authenticatable`,
so no confirmation or unlock email exists. `send_email_changed_notification` is
commented out at `config/initializers/devise.rb:151` (Devise default `false`), so
`email_changed` is inactive. `reconfirmable = true` at `devise.rb:179` is inert
without `:confirmable`. Noticed notifiers
(`Account::AcceptedInviteNotifier`, `Account::OwnershipNotifier`) are
`deliver_by :action_cable` only — no email leg.

Triggers 1 and 2 share one interception point: Devise dispatches both through
`User#send_devise_notification`. Triggers 5–11 share one: `Pay.mailer`
(`pay-11.6.2/lib/pay.rb:78`) is a settable accessor, so the whole Pay family is
redirected by one line in `config/initializers/pay.rb`, with no monkey-patching.

---

## Decision 1 — where interception happens

### Chosen: a custom ActionMailer delivery method (Option A), with mailers that do not render

A `LoopsDelivery` class registered via `ActionMailer::Base.add_delivery_method`,
receiving the built `Mail::Message` and issuing `POST /v1/transactional`. Each
of the three mailer families is overridden to attach its `transactionalId` and
`dataVariables`, and to **skip template rendering**.

**Why Option A over bypassing ActionMailer per trigger (Option B).**

Three levers this repo already relies on survive intact, and Option B rebuilds
each by hand:

1. **The staging kill switch.** `config/environments/staging.rb:65` sets
   `config.action_mailer.perform_deliveries = false`. This is a genuine kill
   switch, not an approximation: `Mail::Message#do_delivery`
   (`mail/lib/mail/message.rb:2145-2153`) checks `perform_deliveries` *before*
   calling `delivery_method.deliver!`, so the Loops API call never happens. This
   is the exact lever COV-46 needs, for free. Option B would need a bespoke one.
2. **Scheduled delivery.** `cancellation_reason` uses
   `deliver_later(wait: 1.hour)`. Option B must hand-roll a job to keep that.
3. **The test harness.** `delivery_method = :test` in the test environment means
   `assert_emails` and `ActionMailer::TestCase` keep working and no HTTP is
   attempted. Option B pushes every test onto WebMock stubs.

`raise_delivery_errors` is left at its default `true` in both production and
staging (the override is commented out at `production.rb:57`), so a Loops API
error propagates out of `deliver!` and fails the job. **Failing the job is not
the same as retrying it** — see the precondition below.

**The honest cost, and how it is paid.** Option A's standard objection is that it
discards work ActionMailer just did and leaves ERB views rendering into a void.
We remove that objection rather than accept it: each overridden mailer calls
`mail(to: ..., body: "")`. `ActionMailer::Base#collect_responses`
(`actionmailer-8.1.3/lib/action_mailer/base.rb:968-976`) short-circuits on a
present `headers[:body]` and never reaches `collect_responses_from_templates`,
so **no template is looked up and no ERB is rendered**. This is not a
micro-optimisation — a rendered body is a live failure mode. A nil in a view
would raise at delivery time and fail a send whose actual content lives in
Loops and was never going to include that view's output.

What this costs, accepted:

- **`ActionMailer::Preview` stops being meaningful.** `test/mailers/previews/account_mailer_preview.rb` previews a body that no longer ships. COV-44 should delete it; Loops' own preview replaces it.
- **`test/mailers/account_mailer_test.rb:11`** asserts on `mail.body.encoded` and **line 8** on `mail.subject`. Both must be replaced with assertions on the Loops payload. This is the only test in the suite touching mail bodies, so the migration cost is one file.
- **Subject lines move to Loops.** `mail.subject` is discarded by the delivery method. `Pay`'s `default_i18n_subject` (`pay-11.6.2/lib/pay.rb:97`) and `account_mailer.invite.subject` go dead alongside the bodies. Loops templates own the subject; keep the i18n keys in place but stop treating them as the source of truth.

**Header smuggling.** `transactionalId` and `dataVariables` ride on the
`Mail::Message` as custom headers (`X-Loops-Transactional-Id`, and
`dataVariables` JSON-encoded into `X-Loops-Data-Variables`). Header values must
be strings, hence the JSON encoding. This is real ugliness and is the price of
the three levers above. It is bounded: `deliver_later` serialises the *mailer
call*, not the message — `ActionMailer::MailDeliveryJob` rebuilds the message
inside the job — so the headers never cross the queue boundary and are not
subject to any transport size limit.

### Precondition: retry does not exist today — in two separate ways

**First: nothing retries a failed mail job.** Verified by booting the app.
`ActionMailer::Base.delivery_job` is `ActionMailer::MailDeliveryJob`, whose
superclass is **`ActiveJob::Base`, not `ApplicationJob`** — so the commented-out
`retry_on` in `app/jobs/application_job.rb:3` would never reach it even if
enabled. Its only rescue handler is `StandardError` →
`handle_exception_with_mailer_class`
(`actionmailer-8.1.3/lib/action_mailer/mail_delivery_job.rb:18`), which delegates
to `mailer_class.handle_exception` and re-raises when the mailer registers no
`rescue_from`. ActiveJob does not retry by default. **A Loops 429 or 500
therefore fails the job permanently on the first attempt, with no backoff.**

Getting retry requires a custom job wired up as
`config.action_mailer.delivery_job`, carrying an explicit
`retry_on LoopsClient::RateLimit, LoopsClient::InternalError,
wait: :polynomially_longer`. This is a real deliverable that no ticket currently
owns; COV-39 or COV-46 should claim it. Rate limiting makes it non-optional —
Loops allows 10 requests/second per team, and billing fan-out doubles the call
count per webhook.

**Second: the queue itself is not durable.**

The usual case for Option A leans on "keeps `deliver_later` → Solid Queue
retry/backoff." **That is currently false and must not be claimed.**

`config/jumpstart.rb` sets `"background_job_processor" => nil`, so
`Jumpstart.config.queue_adapter` is `nil`
(`lib/jumpstart/lib/jumpstart/configuration.rb:207-209`) and the guarded
assignment at `config/environments/production.rb:53` never fires. Production
would fall back to Rails' default `:async` adapter: in-process thread pool, jobs
lost on restart. Staging is explicitly `:inline`
(`config/environments/staging.rb:57`), and production is not provisioned at all
yet — the `render.yaml` production block is commented out pending the cutover
ticket.

Decision 1 does not depend on either gap: the kill switch, scheduled delivery,
and test harness all hold today regardless of adapter. But **both are
preconditions for Loops going live in production** — a custom delivery job with
`retry_on`, *and* Solid Queue enabled (`background_job_processor` in
`config/jumpstart.rb`, plus `SOLID_QUEUE_IN_PUMA` on the production Render
service) to make those retries survive a restart. Without the first, a transient
Loops error drops the email immediately; without the second, it drops on the
next deploy. Recorded here for the cutover ticket and COV-46. Not fixed by
COV-37.

One consequence worth carrying into COV-45: under a real queue adapter,
`deliver_later` returns as soon as the job is **enqueued**, so the Stripe webhook
responds 200 before any Loops call happens. Stripe never observes a Loops
failure and never retries because of one. Job-level retry is the only recovery
path. The "a failed send is absorbed by Stripe's webhook retry" model holds only
under `:inline`.

---

## Decision 2 — transport

### Chosen: `LoopsClient < ApplicationClient`. The `loops_sdk` gem is declined.

The ticket asked for this call to be made with the gem's source open, and set
the tiebreaker: *"If it exposes typed per-status errors that map cleanly, take
the gem. If it raises one generic error class, the mapping work cancels out its
advantage."*

`loops_sdk-2.3.0` was fetched and read. **It raises one generic error class.**
The entire error surface is `lib/loops_sdk/base.rb:8-21`:

```ruby
def handle_response(response)
  case response.status
  when 200, 201
    JSON.parse(response.body)
  when 429
    raise RateLimitError.new(response.headers["x-ratelimit-limit"],
                             response.headers["x-ratelimit-remaining"])
  when 400, 401, 404, 405, 409, 413, 422, 500
    raise APIError.new(response.status, response.body)
  else
    raise APIError.new(response.status, "Unexpected error occurred")
  end
end
```

Two classes total: `RateLimitError` for 429, and `APIError` carrying a
`statusCode` attribute for everything else. Mapping Loops' 401/404/409/422 onto
this project's `Unauthorized`/`NotFound`/`UnprocessableContent` convention would
mean `rescue LoopsSdk::APIError => e` followed by a `case e.statusCode` — a
hand-written reimplementation of exactly what
`ApplicationClient#handle_response`
(`lib/jumpstart/app/clients/application_client.rb:237-258`) already does, on top
of typed per-subclass error constants that `ApplicationClient.inherited`
(line 47-59) generates for free. The tiebreaker resolves against the gem.

Three further findings, all pointing the same way:

- **Global singleton configuration.** `LoopsSdk.configure` sets one process-wide API key on a memoised Faraday connection (`lib/loops_sdk/configuration.rb:9-15`), and every method is a class method on a `Base` subclass. There is no per-instance client, so no second key, no injected test double, and no clean way to vary credentials. `ApplicationClient` is instantiated with `token:`, which is what COV-39's per-environment credentials need.
- **`LoopsSdk::Transactional.send(...)` shadows `Object#send`** (`lib/loops_sdk/transactional.rb:32`).
- **`handle_response` treats 202 and 204 as errors** (line 10 accepts only 200 and 201), raising `APIError` with `"Unexpected error occurred"` on any endpoint that returns them.

**Honest points for the gem, weighed and found insufficient:** it is genuinely
official (`dan@loops.so`, `github.com/Loops-so/loops-rb`, MIT), it covers far
more surface than we need, and it handles attachment key-casing
(`content_type` → `contentType`) for us — about five lines. Its `faraday`
dependency is free; faraday 2.14.3 is already in `Gemfile.lock:151`
transitively. None of that offsets rewriting the error mapping and losing
per-instance credentials.

The ticket flagged that the runtime surface grows from one endpoint to roughly
nine once marketing lands (COV-48+): transactional send, contacts
create/update/find/delete, suppression get/delete, lists, events. At
`ApplicationClient`'s density that is roughly sixty lines of client code — real,
but not enough to buy a global singleton. **No gem approval is needed**, which
also keeps COV-39 unblocked.

`ApplicationClient` handles 401/403/404/422/429/500 out of the box.
`LoopsClient` must add **400** (bad request / transactional email not published),
**409** (conflict — duplicate email/userId, reused idempotency key), and **413**
(payload too large) to `handle_response`, since those currently fall through to
the generic `Error` branch at line 256.

---

## Decision 3 — where `transactionalId`s live

### Chosen: `config/loops.yml` read via `Rails.application.config_for(:loops)`. API key stays in per-environment credentials.

The ticket posed this as conditional on COV-38: separate Loops teams per
environment force credentials; a single shared team makes a checked-in constants
file simpler. **`config_for` satisfies both branches, so the conditional does not
need to be resolved and COV-39 is not blocked on COV-38.**

`transactionalId`s are opaque identifiers (`cll42l54f20i1la0lfooe3z12`), **not
secrets**. Putting non-secrets in credentials makes them invisible to PR review
for no security gain. `config_for` is the boring Rails-conventional answer and
gives us, in one mechanism:

- **Per-environment sections** natively — the separate-teams branch of COV-38.
- **A `shared:` key** that merges into every environment — the single-team branch, without repeating IDs.
- **Diff-reviewable in the PR**, which matters because a wrong `transactionalId` sends the wrong email to a real person and is otherwise invisible.
- **`config_for` raises on a missing environment section**, so a misconfigured deploy fails at boot rather than at first send.

The Loops **API key is a secret** and goes in the per-environment credentials
files COV-31 already established (`config/credentials/staging.yml.enc`,
`config/credentials/production.yml.enc`), read as
`Rails.application.credentials.dig(:loops, :api_key)` — matching the existing
Stripe and Google pattern. This split is the rule: **secrets in credentials, IDs
in `config/loops.yml`.**

Render env vars are rejected: eleven IDs across two environments is eleven
manual dashboard entries per environment with no review trail, and COV-31
deliberately established `RAILS_MASTER_KEY` as the *only* manually-set secret on
Render.

COV-38 still decides the team structure; when it lands it fills in either
`shared:` or per-environment blocks. No architecture changes either way.

---

## Constraints the chosen architecture must handle

### `Pay.mail_to` fan-out — resolved: one API call per recipient, with an idempotency key

`config/initializers/pay.rb:9-17` overrides `Pay.mail_to` to return an **array**
of up to two recipients: the account owner's email, plus `account.billing_email`
when `billing_email?`. `POST /v1/transactional` accepts a single `email` per
request. One `Mail::Message` therefore becomes **N API calls**.

The delivery method iterates `mail.to` and issues one send per address. Partial
failure is the risk: if the second call fails, the job retries and the first
recipient would be mailed twice. Loops supports an **`Idempotency-Key` header**
on transactional sends (max 100 characters), so each send carries a key derived
from a SHA256 of `[transactionalId, recipient, dataVariables]` — 64 hex
characters, within the limit, and stable across job retries because it is
content-derived. A retry re-sends only the calls that did not previously
succeed.

This is correct rather than merely convenient: `reset_password_instructions`
carries a fresh token per request, so its hash differs per send and repeated
resets are not suppressed. Billing emails hash over a charge ID and are
genuinely idempotent.

### The receipt PDF — resolved: link, do not attach

`Pay::UserMailer#receipt` (`pay-11.6.2/app/mailers/pay/user_mailer.rb:3-9`)
populates `attachments[]` at build time. Two paths existed; we take the link.

**Attaching is gated on a Loops support request.** The API docs state
*"Attachments must be enabled on your account before use. Contact
help@loops.so."* That is an account action, and it would make COV-45 depend on a
third party's response time. It also puts a base64-encoded PDF inside a JSON
request body on every successful charge.

Instead, `dataVariables` carries a `receiptUrl` pointing at the hosted invoice
page that already exists — `billing_charge_path` / `invoice_billing_charge_path`
from `config/routes/billing.rb:27-31`, served by
`lib/jumpstart/app/controllers/billing/charges_controller.rb`. The Loops
template renders a link. `mail.attachments` is ignored by the delivery method.

**The link must not be the account-scoped one.** `billing_charge_path` is behind
`authenticate_user!` and account scoping, and `config/initializers/pay.rb:15`
sends to `account.billing_email` — a field whose entire purpose is routing
billing mail to someone who is *not* the account owner (the settings form at
`app/views/billing/_email.html.erb` placeholders it as `account@example.com`).
Sending that recipient a link they cannot open would break the one thing the
field does. COV-45 must use a recipient-agnostic URL; see Open Questions for the
two candidates.

### `dataVariables` are length-capped

Most Loops v1 transactional request body string values are limited to **500
characters**. No long-form content can be passed through `dataVariables` — it
must live in the Loops template. URLs fit comfortably; rendered HTML fragments
do not. This is a hard constraint on how COV-43/44/45 shape their payloads.

### Rate limit

**10 requests per second per team**, shared across transactional and marketing.
Responses carry `x-ratelimit-limit` and `x-ratelimit-remaining`. `LoopsClient`
maps 429 to `RateLimit` (inherited), and the job retry is what applies backoff —
another reason the Solid Queue precondition matters.

### Dead ERB views — resolved: document, do not delete

Under the `body: ""` decision no template is ever looked up, so these files are
inert without being touched. Deleting them is either impossible or costly:

| Location | Owner | Disposition |
| -- | -- | -- |
| `lib/jumpstart/app/views/devise/mailer/*.erb` | vendored Jumpstart engine | **Leave.** Deletable, but edits inside `lib/jumpstart/` conflict on every Jumpstart upgrade. |
| `lib/jumpstart/app/views/account_mailer/*.erb` | vendored Jumpstart engine | **Leave**, same reason. |
| `pay-11.6.2/app/views/pay/user_mailer/*.erb` | the `pay` gem | **Cannot delete.** Gem-owned. |

Recorded instead as an `# AIDEV-NOTE:` on each overridden mailer stating that
the body and subject live in Loops and the ERB templates are unreachable. One
line per mailer, three mailers. This keeps the repo honest for the next reader
without fighting the upgrade path.

---

## Does this block the marketing track?

**No.** `LoopsClient < ApplicationClient` is a plain HTTP client with no
ActionMailer coupling — COV-48's contacts, lists, events, and suppression calls
are additional methods on the same class, reusing the same credential lookup and
the same typed error hierarchy. The ActionMailer delivery method is a *consumer*
of `LoopsClient`, not a layer marketing has to route through. `config/loops.yml`
gains a `mailing_lists:` or `campaigns:` key alongside `transactional_ids:`
without restructuring. Nothing in Decision 1, 2, or 3 forecloses the marketing
track.

---

## Scope

**In:** this document. All three decisions resolved with a chosen answer.

**Deferred / out:**

- Any code, gem, credential, template, or config change (COV-39 onward).
- Loops account and team setup, and authoring the eleven templates (COV-38).
- Marketing and lifecycle architecture (COV-48's brief, not this one).
- Enabling Solid Queue — recorded above as a precondition, fixed by the cutover ticket.

## Open Questions

1. **Which recipient-agnostic receipt URL COV-45 uses.** Two candidates, both viable; the choice is a branding call, not an architecture one, so it is left to COV-45.
   - **Stripe's own hosted receipt.** `Pay::Stripe::Charge` already stores it — `store_accessor :data, :stripe_receipt_url` (`pay-11.6.2/app/models/pay/stripe/charge.rb:9`), populated from `object.receipt_url` during `sync` (line 46), which runs on `charge_succeeded` before the mailer fires. Publicly accessible, no auth, **zero new code**. Cove is Stripe-only (`config/jumpstart.rb`), so the multi-processor gap does not apply. Downside: Stripe-branded, and it is Stripe's payment receipt rather than the `receipts`-gem invoice carrying Cove's business name and address.
   - **A signed receipt route.** `charge.signed_id(purpose: :receipt, expires_in: ...)` plus a controller action that skips `authenticate_user!` — Rails' built-in `ActiveRecord::SignedId`, roughly fifteen lines. Keeps the Cove-branded invoice, which is what a bookkeeper filing for tax actually wants. Downside: a new unauthenticated surface exposing billing data to whoever holds the URL, and an expiry policy to pick.

   Recommendation: the signed route, because `billing_email`'s purpose is serving a non-user recipient and Cove branding is the reason the hosted invoice exists at all. Stripe's URL is the honest zero-code fallback if COV-45 needs to stay small.
2. **Attachment access is no longer needed either way.** Recorded for completeness: requesting attachments from `help@loops.so` remains available but is not on the critical path under either candidate above.
3. **COV-38 team structure** still determines whether `config/loops.yml` uses `shared:` or per-environment blocks. The architecture is identical either way; only the YAML shape changes.

## More Info

- The reset link uses `edit_password_url(@resource, reset_password_token: @token)` (`lib/jumpstart/app/views/devise/mailer/reset_password_instructions.html.erb:5`) — Jumpstart's helper, **not** Devise's default `edit_user_password_url`. COV-43 must build this URL by hand into `dataVariables`, since the view that generated it no longer renders.
- `Pay.mailer` (`pay-11.6.2/lib/pay.rb:78-88`) is a settable accessor used by every webhook, so all seven Pay triggers are redirected by one line in `config/initializers/pay.rb`. No monkey-patching of `Pay::UserMailer` is required.
- `Pay.send_email?` (`pay-11.6.2/lib/pay.rb:123-130`) already gates each billing email independently via `Pay.emails.*`. Note `subscription_renewing` defaults to yearly recurring plans only.
- `config.parent_mailer = "ApplicationMailer"` (`config/initializers/devise.rb:52`) means Devise mail inherits `default from: Jumpstart.config.default_from_email`. Under Loops the `from` address is owned by the Loops template and the verified sending domain, not by this setting.
