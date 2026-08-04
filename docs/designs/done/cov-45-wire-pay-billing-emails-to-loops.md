> Ticket: COV-45
> Branch: feature/cov-45-wire-pay-billing-emails-to-loops
> Plan created: docs/plans/cov-45-wire-pay-billing-emails-to-loops.md

# Feature: Wire Pay billing emails to Loops

## Problem

Seven published billing templates have no application delivery path. Pay 11.6.2
triggers them from Stripe webhooks and `Pay.mail_to` can return both the account
owner and an optional billing contact, while Loops accepts only one recipient
per request. The integration must fan out safely without suppressing a billing
contact, duplicating a replayed notification, or suppressing a later legitimate
billing event that happens to have the same template variables.

## Approach

Implement COV-37's chosen ActionMailer delivery architecture by adding a host-app
`Pay::UserMailer` shadow at `app/mailers/pay/user_mailer.rb`. Rails load-path
precedence makes the host class win over Pay 11.6.2's class; do not monkeypatch
`Pay::UserMailer`, configure another Pay mailer, fork the gem, or change Pay's
webhook handlers.

The shadow inherits from `Pay.parent_mailer.constantize`, defines all seven Pay
actions explicitly, and retains the gem's private `mail_arguments` semantics so
the unchanged `Pay.mail_to` continues to supply recipients. A small private
`loops_mail` helper centralizes transactional-ID lookup, data-variable headers,
the stable notification seed, `body: ""`, and `mail mail_arguments`. Each public
action remains explicit about its variables and seed. The empty body prevents
Pay's vendored ERB templates from rendering because Loops owns the subject and
content.

Extend the existing Loops transport rather than bypassing ActionMailer:

- Add the seven non-secret IDs to `config/loops.yml`.
- Add an internal `X-Loops-Idempotency-Seed` header for billing mail.
- Let `LoopsDelivery` deduplicate exact recipient addresses and issue one API
  request per remaining address.
- Extend `LoopsClient` key derivation to combine transactional ID, recipient,
  and the billing notification's stable seed. Existing callers without a seed,
  including Devise, retain the current canonical data-variable fallback.
- Translate ActionMailer attachments to Loops' `filename`, `contentType`, and
  base64 `data` objects. The receipt requires its generated PDF; missing or
  failed PDF generation aborts delivery.

This keeps the staging kill switch, ActionMailer test adapter, delivery-job
retries, scheduled delivery behavior, and Pay webhook call sites intact.

## Acceptance Criteria

- Each of the seven actions builds a bodyless Loops-backed mail message with its
  correct published `transactionalId` and exact data-variable contract.
- The host shadow exposes all seven expected public actions. A compatibility
  test fails if this explicit contract changes, prompting a re-check on every
  Pay upgrade.
- With a distinct `account.billing_email`, delivery issues exactly two Loops
  requests, one per recipient, with different idempotency keys.
- With `billing_email` blank, delivery issues exactly one request.
- When the billing address equals the owner's address, delivery deduplicates it
  and issues one request.
- The two-recipient regression test asserts the exact different key expected for
  each recipient. A same-key second request returning 409 must leave the second
  expected request unobserved and fail the test; merely asserting two calls is
  insufficient.
- Rebuilding the same logical notification produces the same key for each
  recipient, so a replay returns 409 and is absorbed rather than duplicated.
- Separate partial refunds, renewal cycles, payment attempts, and changed trial
  periods produce different notification seeds and are not incorrectly
  suppressed.
- Receipt variables are `amount`, `charged_to`, `transaction_id`, `charged_at`,
  and `extra_billing_info` only when present. Inline billing information is
  capped at the first 500 characters; the PDF retains the full value.
- Refund variables are `amount_refunded`, `charged_to`, `transaction_id`,
  `charged_at`, and `extra_billing_info` only when present, with the same inline
  cap.
- The receipt sends the Pay-generated PDF using its receipt filename,
  `application/pdf`, and strict base64 data. Missing attachment generation fails
  before any incomplete receipt is sent.
- `payment_action_required` carries `confirm_payment_url` from
  `pay.payment_url(params[:payment_intent_id])`.
- Renewal and both trial actions carry an absolute `manage_subscription_url` to
  Cove's existing `/billing` page. `payment_failed` carries the same absolute
  page as `update_billing_url`.
- Mail display names resolve to plain recipient addresses before sending.
- Missing IDs, seeds, required variables, URLs, malformed headers, and permanent
  Loops errors fail loudly rather than skipping a recipient.
- Existing 409 handling remains successful duplicate suppression. Existing job
  retry behavior remains unchanged.
- `bin/rails test` passes with output shown during execution.
- `bin/rubocop` is clean.
- The final `git diff` is reviewed and reported.
- The `pay` gem, `lib/jumpstart/`, existing `Pay.emails.*`, and
  `config/initializers/pay.rb` behavior remain untouched.

## Prototype

None. The seven published COV-42 Loops templates lock the user-facing subjects,
copy, hierarchy, responsive presentation, and plain-text alternatives. COV-45
supplies their data and transport only; it does not edit or preview templates.

## Data Model

No database models, migrations, associations, routes, or credentials change.

Add the published IDs to the existing shared `config/loops.yml` transactional
map:

| Action | Published transactional ID |
| --- | --- |
| `receipt` | `cmsdrk6tf03rb0jzw194l0rl5` |
| `refund` | `cmsdrk8f603rc0jzn1pmslh4m` |
| `subscription_renewing` | `cmsdru6vf04dv0j15pwbonmxs` |
| `payment_action_required` | `cmsdrxthi04p90jzc3bwkq7kj` |
| `payment_failed` | `cmsdrxtnb04qk0j3oclaszs7k` |
| `subscription_trial_will_end` | `cmsdru71a04c50jzw6rqtt95u` |
| `subscription_trial_ended` | `cmsdru76v04ep0jw7xrbb236w` |

These IDs are configuration, not secrets. The Loops API key remains in
per-environment Rails credentials.

### Data-variable contracts

| Action | Required variables | Optional variables |
| --- | --- | --- |
| `receipt` | `amount`, `charged_to`, `transaction_id`, `charged_at` | `extra_billing_info` |
| `refund` | `amount_refunded`, `charged_to`, `transaction_id`, `charged_at` | `extra_billing_info` |
| `subscription_renewing` | `renews_on`, `manage_subscription_url` | None |
| `payment_action_required` | `confirm_payment_url` | None |
| `payment_failed` | `update_billing_url` | None |
| `subscription_trial_will_end` | `manage_subscription_url` | None |
| `subscription_trial_ended` | `manage_subscription_url` | None |

`email` remains the separate top-level Loops recipient field. Money is
preformatted with Pay's currency helpers. Charge times are localized by Rails;
the renewal date uses the localized long-date format. `extra_billing_info` is
omitted when blank and otherwise capped at 500 characters. Both management URLs
use the absolute `billing_url`; the confirmation URL uses Pay's existing helper.

### Stable notification seeds

The seed identifies the logical notification before recipient fan-out. The
client hashes `[transactionalId, recipient, seed]`, producing a recipient-specific
key within Loops' 100-character limit. The seed itself is not persisted or sent
as a template variable.

| Action | Stable seed inputs | Why |
| --- | --- | --- |
| `receipt` | Stripe charge processor ID | One successful-charge notification |
| `refund` | Stripe charge processor ID + cumulative refunded amount | A replay is stable; a later partial refund remains distinct |
| `subscription_renewing` | Stripe subscription processor ID + renewal timestamp | A replay is stable; the next renewal cycle remains distinct |
| `payment_action_required` | Stripe payment-intent ID | One confirmation requirement per intent |
| `payment_failed` | Stripe invoice ID + `attempt_count` | A replay is stable; a later scheduled attempt remains distinct |
| `subscription_trial_will_end` | Stripe subscription processor ID + trial-end timestamp | A changed or extended trial remains distinct |
| `subscription_trial_ended` | Stripe subscription processor ID + trial-end timestamp | A changed or extended trial remains distinct |

Stripe defines `attempt_count` as the invoice payment-attempt counter from the
retry schedule. Upcoming renewal invoices have no durable invoice ID, so the
subscription plus Stripe-provided renewal timestamp is the stable identity for
that action.

### Receipt attachment contract

`receipt` generates the same Pay PDF before calling the shared mail helper. It
must produce exactly one attachment using:

- `filename`: `params[:pay_charge].receipt_filename`
- `contentType`: `application/pdf`
- `data`: strict base64 encoding of the decoded attachment bytes

`LoopsDelivery` maps ActionMailer attachments into the API payload, and
`LoopsClient#send_transactional` accepts that attachment array. The complete
request remains subject to Loops' less-than-4-MB JSON limit. A missing receipt
or payload-too-large response is a hard failure; do not silently send without
the PDF and do not fall back to an authenticated Cove receipt URL.

## Screens / Flows

### Billing webhook to email

1. Stripe invokes one of Pay 11.6.2's existing webhook handlers.
2. The handler uses the unchanged `Pay.mailer`, which resolves to the host-app
   `Pay::UserMailer` shadow.
3. The relevant explicit action formats its published variables, stable seed,
   and absolute URLs. Receipt also generates and attaches the PDF.
4. The shared helper fetches the checked-in transactional ID, attaches the three
   internal headers, preserves `mail_arguments`, and builds a message with an
   empty body.
5. ActionMailer invokes `LoopsDelivery`. Exact duplicate addresses are removed;
   every remaining recipient becomes one `LoopsClient` request with its own
   derived key and the same variables and attachments.
6. Loops renders and sends the published COV-42 content. The existing Cove
   billing page handles both subscription management and billing-information
   updates.

No Rails screen, navigation, component, email template, subject, or copy changes.

### Existing delivery timing

- `receipt`, `refund`, `subscription_renewing`,
  `payment_action_required`, and both trial actions keep their existing
  `deliver_later` call sites.
- `payment_failed` currently uses `deliver_now` in Pay 11.6.2 and remains
  synchronous. This corrects the ticket's broader retry premise without
  changing the gem.
- `subscription_trial_will_end` and `subscription_trial_ended` remain mutually
  exclusive `if`/`elsif` branches of the same Pay webhook handler.

## Scope

**In:** The host `Pay::UserMailer` shadow with all seven actions and a private
shared helper; seven checked-in transactional IDs; exact variables and URLs;
receipt PDF generation and forwarding; recipient deduplication and fan-out;
billing-specific stable notification seeds; backward-compatible Loops client
and delivery-method extensions; mailer, transport, attachment, fan-out,
idempotency, replay, distinct-event, error, and Pay-shadow compatibility tests.

**Deferred:** Devise/auth email behavior (COV-43); account email behavior
(COV-44); staging delivery behavior (COV-46); end-to-end live inbox verification
(COV-47); template content or settings; changes to `Pay.emails.*`,
`Pay.mail_to`, Pay webhook handlers, the Pay gem, or `lib/jumpstart/`; new receipt
routes; best-effort delivery or bespoke Honeybadger reporting.

## Open Questions

None.

## More Info

- COV-37 chose an ActionMailer delivery method so the staging kill switch,
  scheduled mail, delivery jobs, and test adapter remain available.
- COV-39 supplied `LoopsClient`, recipient-aware content-derived keys,
  recipient fan-out in `LoopsDelivery`, typed errors, and
  `LoopsMailDeliveryJob`. COV-45 extends those contracts without changing
  existing callers that do not supply a seed.
- COV-42 published all seven templates and superseded COV-37's earlier
  link-not-attachment decision after Loops support enabled attachments for Cove.
  The receipt must forward the PDF; it has no `receipt_url` variable.
- Loops' transactional API accepts one `email`, optional `dataVariables`, and an
  `attachments` array of `filename`, `contentType`, and base64 `data`. Reusing an
  idempotency key within 24 hours returns 409 instead of replaying the original
  response. The complete JSON body must remain below 4 MB.
- If the first recipient succeeds and the second fails, the whole delivery
  attempt fails. A job or Stripe replay rebuilds the same keys: the first
  recipient's 409 is absorbed and the second recipient is tried again.
- Production uses Solid Queue and the custom mail delivery job retries Loops
  rate limits, internal errors, and network timeouts. Staging uses `:async` but
  `perform_deliveries = false`, so COV-45 makes no staging Loops calls.
- A host shadow does not inherit methods from the gem class because the gem file
  never loads. Defining all seven methods and reviewing the shadow on every Pay
  upgrade are mandatory.
