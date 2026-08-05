> Ticket: COV-52
> Branch: feature/cov-52-unsubscribe-and-suppression-reconciliation
> Plan created: docs/plans/cov-52-loops-unsubscribe-webhook.md

# Feature: Loops unsubscribe and suppression webhook

## Problem

When someone unsubscribes, hard bounces, or reports spam in Loops, Cove never
finds out. The account settings page then lies about the user's marketing
state, and Cove sits one careless write away from re-subscribing someone who
opted out.

## Approach

**Build the inbound webhook, not a reconciliation poller.** The ticket was
written before COV-48 Decision 0 established that Loops has signed inbound
webhooks, and instructs us to build the webhook instead if so. Loops pushes
`contact.unsubscribed`, `contact.mailingList.unsubscribed`, `email.unsubscribed`,
`email.spamReported`, `email.hardBounced`, and `email.resubscribed`; requests are
signed HMAC-SHA256 and retried roughly 8 times over 24 hours with `Webhook-Id`
as the idempotency key.

A `POST /webhooks/loops` endpoint verifies the signature, dedupes on
`Webhook-Id` via a unique index, responds 200 immediately, and processes each
event in a background job that mirrors Loops-side state into the existing
`User::MarketingConsent` columns.

**The reconciliation sweep is deferred.** COV-48 demotes it to a backstop for
events lost *beyond* Loops' 24-hour retry window — an outage shorter than that
self-heals. Loops has no bulk contact read, so a sweep is
`GET /v1/contacts/find` once per user against the shared 10 req/sec budget. It
should not be designed before the webhook has a track record.

**No suppression polling.** Suppression is learned from `email.hardBounced` and
`email.spamReported` events. The pre-opt-in `GET /v1/contacts/suppression` check
stays deferred, as COV-48 Edge Cases already decided.

**This ticket makes zero outbound Loops API calls.**

### Two things already true before this ticket

Both are the ticket's own acceptance criteria, already satisfied by merged code.
COV-52 adds tests naming them, not mechanisms.

1. **App-side sync cannot re-subscribe a Loops-side opt-out.**
   `LoopsContactSynchronizer#current_app_opt_in?` refuses when
   `marketing_opt_in_source == "loops"`, `current_app_opt_out?` fires only for
   `user_app`, and the `email_change` intent omits `subscribed` entirely.
2. **Re-opt-in after a Loops unsubscribe** — COV-49 ships the disabled toggle
   and its explanatory copy for all five opt-out reasons.

## Acceptance Criteria

- A validly signed webhook is accepted, recorded, and responded to with 200.
- A request with a missing, malformed, or incorrect signature is rejected 401
  and records nothing.
- Malformed JSON is rejected 400.
- `contact.unsubscribed` and `email.unsubscribed` opt the user out with reason
  `user_loops`.
- `contact.mailingList.unsubscribed` for the Cove updates list opts the user out
  with reason `mailing_list_unsubscribe`; for any other list it records the event
  and changes no state.
- `email.spamReported` opts the user out with reason `spam_report`.
- `email.hardBounced` opts the user out with reason `hard_bounce`.
- `email.resubscribed` opts the user back in with source `loops`, unless the
  existing opt-out reason is `spam_report` or `hard_bounce`.
- A less severe opt-out reason never overwrites a more severe one; a more severe
  one does overwrite. `marketing_opt_out_at` keeps the earliest timestamp.
- Redelivering the same `Webhook-Id` returns 200 and changes nothing.
- An event whose `event_time` predates the state it would overwrite is ignored.
- An event for an unknown `userId` and unknown email is recorded, marked
  processed, logged, and dropped without error.
- **No webhook-driven state change enqueues a contact sync back to Loops** — the
  central regression guard.
- Signature verification fails closed where no `loops.webhook_secret` is
  configured.
- Events older than 30 days are pruned.
- `bin/rails test` passes, `bin/rubocop` is clean, and the final `git diff` is
  reviewed.

### Criteria from the ticket that this design makes inapplicable

Recorded rather than dropped, so the change is visible at review.

- *"Reconciliation respects the rate-limit throttle"* — nothing to throttle;
  there are no outbound calls.
- *"A suppressed contact is recorded as unsendable"* — satisfied via the
  `email.hardBounced` / `email.spamReported` events rather than
  `GET /v1/contacts/suppression`.
- *"Live compliance check on staging"* — **not achievable.** Loops allows one
  webhook endpoint per account and it points at production (COV-48 Decision 2),
  so staging receives no events. The honest equivalent is running the check on
  production once COV-56's first campaign exists. The dashboard's
  `testing.testEvent` can verify endpoint wiring in the meantime.

## Prototype

None. No user-facing UI changes. The COV-49 settings toggle and its copy are
unchanged.

## Data Model

One new table. No changes to the `users` table.

### `loops_webhook_events`

| Column | Type | Notes |
| -- | -- | -- |
| `webhook_id` | `string` | `null: false`, unique index — the `Webhook-Id` header |
| `event_name` | `string` | `null: false` |
| `event_time` | `datetime` | from the payload, not receipt time |
| `payload` | `jsonb` | `null: false`, `default: {}` |
| `processed_at` | `datetime` | nil until the job succeeds |
| `created_at` / `updated_at` | `datetime` | |

**The unique index is the dedupe mechanism.** `create!` raising
`RecordNotUnique` is the check, which is atomic against two concurrent retries
in a way a read-then-write cache lookup is not.

**`payload` is stored deliberately.** "Why does Cove think I unsubscribed" is
then one query, at negligible cost.

**`processed_at` separates received from acted on.** Without it, a job crashing
mid-processing leaves the event recorded, its retry deduped, and the opt-out
silently lost — the exact failure this ticket exists to prevent.

**No foreign key to `users`.** Events legitimately arrive for contacts with no
matching user (deleted account, or a manual dashboard add); a FK would turn
COV-48's "log and drop" into an exception.

**Retention: 30 days**, pruned by the first real entry in `config/recurring.yml`
(currently all commented-out examples). COV-48 requires longer than the 24-hour
retry window and suggests a week; 30 days costs almost nothing at Cove's volume
and makes the table a usable audit trail.

### Additions to `User::MarketingConsent`

No new columns.

- `record_loops_opt_out(reason:, occurred_at:)` — applies the severity ordering,
  escalates the reason, keeps the earliest `marketing_opt_out_at`, no-ops when
  the existing reason is equally or more severe.
- The `user_loops` protection is narrowed: the in-app toggle still refuses (so
  COV-49's copy stays true), but the webhook resubscribe path may clear it.

### Configuration

`loops.webhook_secret` in per-environment credentials, following COV-31's
pattern. Production only. **Not** in `config/loops.yml` — that file holds
non-secrets.

## Screens / Flows

### Receiving an event

1. Loops POSTs to `/webhooks/loops` with `Webhook-Signature`, `Webhook-Id`, and
   `Webhook-Timestamp`.
2. The controller verifies HMAC-SHA256 over
   `"#{webhook_id}.#{timestamp}.#{raw_body}"`. Bad signature → 401, nothing
   recorded.
3. Dedupe on `Webhook-Id`. Already seen → 200 immediately, no processing.
4. Record the event, respond **200**, process asynchronously. A slow user lookup
   never holds Loops' connection open.
5. The job resolves `contactIdentity.userId` → `User`, falling back to email.
   No match → log, mark processed, drop.
6. On success, set `processed_at`.

CSRF verification and authentication are skipped on this controller.

### Event mapping

Six handled; every other event is recorded and ignored.

| Event | Effect | Reason / source |
| -- | -- | -- |
| `contact.unsubscribed` | opt out | `user_loops` |
| `email.unsubscribed` | opt out | `user_loops` |
| `contact.mailingList.unsubscribed` | opt out *only for the Cove updates list* | `mailing_list_unsubscribe` |
| `email.spamReported` | opt out | `spam_report` |
| `email.hardBounced` | opt out | `hard_bounce` |
| `email.resubscribed` | opt **in**, unless protected | source `loops` |

All five opt-out reasons and their settings-page copy already exist from COV-49.

### Opt-out reason severity

`spam_report` > `hard_bounce` > `mailing_list_unsubscribe` > `user_loops`

A hard bounce fires `email.hardBounced` **and** `contact.unsubscribed`, in
arbitrary order. A naive "already opted out, skip" guard would drop the accurate
`hard_bounce` in favour of whichever arrived first. A more severe reason
therefore overwrites a less severe one and never the reverse, while
`marketing_opt_out_at` retains the earliest timestamp. This matters because the
settings page renders different copy per reason, and "we couldn't deliver to
this address" is the true one.

### Resubscribe

`email.resubscribed` routes through the existing
`grant_marketing_consent(source: "loops")`, which already refuses when
`marketing_opt_out_protected?`. So a resubscribe cannot clear `spam_report` or
`hard_bounce`.

It **can** clear `user_loops` and `mailing_list_unsubscribe`: the user
unsubscribed in Loops and resubscribed in Loops, Loops is sending to them again,
and refusing would leave Cove's settings page lying in the opposite direction.
COV-48's Edge Cases already treat a preference-center resubscribe as genuine
consent — a deliberate user action on a page we sent them to — which is why
`marketing_opt_in_source` accepts `loops` at all.

### Webhook registration (manual, dashboard-only)

Settings → Webhooks in the Loops dashboard. No API endpoint, no CLI verb, and
**one endpoint per Loops account**.

- URL: `https://covehomeschool.com/webhooks/loops`
- Secret: shown once, in the form `whsec_<base64>`; stored in
  `config/credentials/production.yml.enc` under `loops.webhook_secret`.

Registration can happen before or after this ships — Loops' retry schedule means
a 404 during the gap self-heals.

## Edge Cases

- **Replay.** No timestamp tolerance is enforced. Loops documents none, and its
  retries span 24 hours, so a tight window would reject legitimate retries.
  `Webhook-Id` dedupe is the replay defence, and it is sound **only because**
  retention (30 days) outlives the retry window (24 hours). That relationship
  between the two numbers belongs in an `AIDEV-NOTE`.
- **Non-production fails closed for free.** Staging and development carry no
  `loops.webhook_secret`, so verification cannot succeed. No environment guard
  is needed — unlike COV-51, which required `contact_sync_enabled` because it
  made outbound calls.
- **Identity resolution.** `userId` first, then email. The email fallback is
  correct specifically for `email.hardBounced` and `email.spamReported`, which
  per COV-48 Decision 5 are facts about an *address*, not a person.
- **Out-of-order delivery.** A user opts in via the app at T2 and a webhook from
  T1 arrives late; applied naively it opts them back out. Every state change
  compares the payload's `event_time` against the user's current consent
  timestamps and ignores events older than the state they would overwrite. Same
  defensive shape as COV-51's reload-before-write.
- **Nothing echoes back to Loops.** Webhook opt-outs set a reason other than
  `user_app`; webhook opt-ins set source `loops`. `enqueue_contact_sync` already
  declines both. This holds today by happy accident of COV-51's design rather
  than by anything named, so it needs an explicit regression test.
- **Mailing-list unsubscribe for another list.** Recorded, no state change. Only
  one list exists today; this should not need revisiting when a second does.
- **Job failure.** `processed_at` stays nil and the row is retryable. Every
  operation is idempotent, so a re-run converges. Standard ActiveJob retry — no
  `LoopsRetryable`, because there are no HTTP calls.
- **Account deletion.** The user row is gone and COV-51's `after_destroy` hook
  deletes the Loops contact. A trailing `contact.deleted` or
  `contact.unsubscribed` finds no user and drops. Suppression is email-keyed and
  survives independently, so a spam complainant who deletes and re-registers is
  still suppressed — deletion is not an escape hatch (COV-48 Decision 5).
- **Unknown or unhandled event names.** Recorded and marked processed. Loops
  sends 15+ event types on one endpoint; open/click/delivered traffic must not
  raise.

## Scope

**In:** the `POST /webhooks/loops` endpoint; HMAC-SHA256 signature verification;
the `loops_webhook_events` table and `Webhook-Id` dedupe; asynchronous
processing; the six-event mapping; opt-out reason severity; `event_time`
ordering guards; the narrowed `user_loops` protection; the 30-day pruning job;
the webhook secret in production credentials; tests.

**Deferred:** the reconciliation sweep; any `GET /v1/contacts/suppression` call,
including the pre-opt-in check; suppression removal
(`DELETE /v1/contacts/suppression`, quota-limited and treated as one-way);
per-environment webhook endpoints; admin UI for the event log; campaign and
workflow content (COV-55, COV-56).

## Open Questions

None.

## More Info

- **Signature detail COV-48 got slightly wrong.** The brief says the secret is
  "base64-decoded." Loops' actual scheme strips the prefix first —
  `secret.split('_')[1]`, then base64-decode, then HMAC-SHA256. Confirmed
  against `https://loops.so/docs/webhooks`. Getting this wrong means every event
  silently fails verification.
- **`testing.testEvent`** can be fired from the Loops dashboard to verify
  endpoint wiring without waiting for real traffic.
- **Retry behaviour**, confirmed by `help@loops.so` on 2026-08-03 and
  undocumented on the webhooks page: roughly 8 attempts over 24 hours with
  exponential backoff and jitter; `Webhook-Id` is the correct idempotency key.
- **Webhook dispatch is rate-limited to 10 events/sec**, remainder queued.
  Inbound only — it does not consume the API budget shared with transactional
  sends.
- **Routes** are modularised under `config/routes/`; this adds a new file drawn
  from `config/routes.rb`, matching the existing pattern.
- **COV-48 Decision 1's structural rule remains the real protection:** the app
  never sends `subscribed: true` except in direct response to a consent-granting
  user action. Correctness does not depend on this ticket existing — COV-52
  makes Cove's own state honest, and COV-48's Decision 1 is explicit that a
  missed unsubscribe is a data-integrity and trust problem, not a CAN-SPAM
  exposure, because Loops refuses to send to its own unsubscribes regardless of
  what Cove believes.
