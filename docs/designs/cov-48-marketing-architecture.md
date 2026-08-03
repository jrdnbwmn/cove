> Ticket: COV-48
> Branch: feature/cov-48-marketing-consent-contact-sync

# Decision brief: marketing consent, contact sync, and source of truth

## Problem

Marketing email needs two things transactional email does not: a **contact
record in Loops**, and a defensible record of consent. Transactional email is
sent because a user took an action. Marketing email is sent because someone
agreed to receive it — and that agreement has to be recorded, honored, and
revocable.

This brief resolves the five decisions that shape COV-49, COV-50, COV-51, and
COV-52.

**No code, schema, migrations, or Loops configuration are produced by this
ticket.** Everything below is a decision, not an implementation.

---

## Decision 0 — the webhook question, answered

**Loops has inbound webhooks.** The API reference the ticket was written from was
partial. `https://loops.so/docs/webhooks` documents a signed webhook carrying,
among others:

| Event | Meaning |
| -- | -- |
| `contact.unsubscribed` | "Sent when a contact is unsubscribed from your audience" |
| `contact.mailingList.unsubscribed` | Unsubscribed from a specific mailing list |
| `contact.created`, `contact.deleted` | Contact lifecycle |
| `email.unsubscribed`, `email.resubscribed` | Per-email unsubscribe / resubscribe |
| `email.spamReported` | Recipient marked the mail as spam |
| `email.hardBounced` | Permanent delivery failure |

A hard bounce automatically unsubscribes the contact from the audience, firing
`contact.unsubscribed` alongside `email.hardBounced`.

Payloads carry `eventName`, `webhookSchemaVersion` (`"1.0.0"`), `eventTime`, and
context-dependent `contact`, `contactIdentity`, `email`, `mailingList(s)`,
`campaignId`, `loopId`, `transactionalId`, `sourceType`. Requests are signed
HMAC-SHA256 over `"${eventId}.${timestamp}.${rawBodyText}"` with a
base64-decoded secret, and carry `Webhook-Signature`, `Webhook-Id`, and
`Webhook-Timestamp` headers.

**So the failure mode the ticket was built around does not exist.** A user who
clicks the footer unsubscribe link is not invisible to Cove — the event is
pushed to us. This does not make "app is authoritative" safe on its own
(webhooks get missed, delayed, and misconfigured), but it demotes the scheduled
reconciliation sweep from primary mechanism to backstop, and it shrinks COV-52
substantially.

### The constraint this creates

> *"Currently you can only set up one webhook endpoint per Loops account."*

Configuration is **dashboard-only** — Settings → Webhooks. There is no API
endpoint for it and no `loops webhooks` verb in the CLI (`loops --help`, v1
command list). Dispatch is rate-limited to 10 events/sec with the remainder
queued.

**Retry behaviour, confirmed by `help@loops.so` 2026-08-03** (undocumented on the
webhooks page): a failed delivery is retried **roughly 8 times over 24 hours**,
with exponential backoff and jitter, and **`Webhook-Id` is the correct
idempotency key**. Two consequences, both load-bearing:

- Deduplication is **required**, not defensive over-engineering, and the dedupe
  record must be retained **longer than the 24-hour retry window** — otherwise a
  late retry is processed a second time as if it were new.
- **An outage shorter than 24 hours is self-healing.** Loops replays what we
  missed. This shrinks COV-52 again: reconciliation only needs to catch events
  lost *beyond* the retry window, which is a much rarer failure than "the
  endpoint was briefly down."

COV-38 Decision 2 put staging and production on **one shared Loops team**, so
there is exactly one webhook URL for both environments. Resolved in Decision 2
below.

### Two further API facts that shaped this brief

1. **There is no "list all contacts" endpoint.** The only contact read is
   `GET /v1/contacts/find?email=` or `?userId=` — one contact per call. A
   reconciliation sweep therefore cannot page the audience; it must iterate
   *our* users and call `find` once each, against the 10 req/sec budget shared
   with transactional sends. Reconciliation is a slow drip, not a bulk job.
2. **`PUT /v1/contacts/update` is an upsert**, and *"If you need to change a
   contact's email address, the contact must already have a `userId`."* Without
   `userId`, an email change orphans the old contact and creates a second one.
   This settles Decision 3 on its own.

---

## Approach

### Decision 1 — split authority, enforced by a structural rule

**The app is authoritative for opt-in and holds the provenance. Opt-out is
terminal and may be written by either side. The webhook is the fast path; a
reconciliation sweep is the backstop.**

This is the ticket's Option C invariant with Option B's mechanism. But the rule
that actually prevents the failure mode is not "who wins" — it is this:

> **The app never sends `subscribed: true` except in direct response to a user
> action that grants consent. Every routine sync — name change, property
> update, email change — omits the `subscribed` key entirely.**

`PUT /v1/contacts/update` is a partial update: omitting `subscribed` leaves
Loops' value untouched. So re-subscribing someone who opted out becomes
**structurally impossible rather than merely unlikely**, and it stays impossible
if the webhook is down, misconfigured, or COV-52 never ships. Correctness does
not depend on a background job existing.

**The residual risk, stated precisely.** The ticket frames a missed unsubscribe
as a CAN-SPAM exposure. It is not. Loops will not send marketing to an
unsubscribed contact regardless of what the app believes, so a missed event does
not send unwanted mail. What it does is make the account-settings page **lie
about the user's state**, and leave us one careless write away from
re-subscribing them. That is a serious data-integrity bug and a trust problem —
but it is not a legal one, and the brief should not claim otherwise.

**Four events collapse to opt-out**, recorded with distinct reasons:
`contact.unsubscribed`, `contact.mailingList.unsubscribed`, `email.spamReported`,
`email.hardBounced`. The reasons matter because a hard bounce is a
*deliverability* fact, not a withdrawal of consent — the settings page must say
"we couldn't deliver to this address," not "you unsubscribed."

**Reconciliation is deferred to COV-52.** With no bulk read endpoint it is
O(users) API calls, so it wants to be low-frequency and paced. It should not be
designed before the webhook has a track record.

### Decision 2 — the webhook endpoint points at production only

One endpoint per account, dashboard-configured. Staging never receives contact
events. This is consistent — staging already sends nothing — and the handler
remains fully testable from fixtures plus a signature helper; what staging loses
is only the live round trip.

Recorded as a known limitation of COV-38 Decision 2's shared team. The escape
hatch, if it ever bites, is the second team COV-38 already priced out. A relay
from production to staging was considered and rejected as more machinery than
the problem justifies.

### Decision 3 — one channel, one mailing list, contacts created only on opt-in

Cove has **one marketing channel**. It maps to one public Loops mailing list
("Cove updates"), created by COV-53. The app's consent state maps to both
audience `subscribed` and membership of that list. With a single channel,
list-level and audience-level opt-out mean the same thing to us, so both events
land on the same terminal state.

**Contacts are created only on opt-in.** No Loops contact exists for a user who
never consented.

This narrows COV-51 — "Sync users to Loops contacts" becomes "sync *consented*
users." Three reasons:

- It is the cleanest possible consent story: the **absence** of a contact is
  itself the evidence that nobody was mailed without agreeing.
- It keeps the free plan's 1,000-contact ceiling from filling with people who
  will never be mailed (COV-38 Findings).
- Nothing depends on it. Transactional needs no contact — COV-37 established
  `addToAudience: false` on every send.

**Double opt-in is not available on this path and is not being built.** Loops'
double opt-in applies only to its own form endpoints, **not** to the API
create/update contact endpoints, so creating contacts from Rails bypasses it
entirely. An unchecked checkbox on a form behind registration is defensible on
its own; revisit if list quality or abuse ever becomes a real signal.

### Decision 4 — checkbox at registration and a settings toggle; backfill is a no-op

Opt-in is captured in two places, **both unchecked / off by default**:

1. A checkbox on the registration form (`app/views/devise/registrations/new.html.erb`).
2. A toggle in account settings (`app/views/devise/registrations/edit.html.erb`).

**Existing users are backfilled as not-opted-in.** Cove is pre-launch, so this
population is effectively zero and the rule generates no migration work and no
in-app prompt. The rule is recorded anyway because it is the only defensible
reading: they never agreed. Under no circumstances is a "we've added you to our
newsletter" email sent — that is itself marketing to someone who never
consented.

**The invitation-accept flow does not get a checkbox.** That form already
carries terms-of-service acceptance (`User::Agreements` validates
`terms_of_service` on `:invitation_accepted`), and stacking marketing consent
onto an acceptance the user must tick to proceed is bundled consent. Invited
users default to opted-out and use the settings toggle.

### Decision 5 — `userId` is `User#id` as a string; deletion deletes the contact

**Identity.** `userId` is `User#id` rendered as a string — plain, not prefixed.
It is the app's stable primary key; `userId` is already its own namespaced field
in Loops, so a prefix disambiguates nothing; and a prefix would mean parsing on
every webhook read forever. This is the expensive-to-change decision in this
brief — changing it later is a migration across every synced contact.

Setting it is not optional: per the API reference, an email change requires the
contact to already carry a `userId`. Without it, a user changing their email
address orphans their contact and creates a duplicate.

**Deletion.** When a user deletes their account, the Loops contact is
**deleted** (`POST /v1/contacts/delete`), with no tombstone kept in Cove.

- Suppression is the wrong tool. `DELETE /v1/contacts/suppression` carries a
  removal quota, so suppression is not freely reversible, and no flow here
  should depend on un-suppressing at will.
- Keeping a tombstone of someone's email address after they asked to be deleted
  is itself the privacy problem being avoided.
- A user who re-registers re-consents through the same unchecked checkbox, so
  nothing is lost that should have been kept.

**Suppression is keyed on email address only** — confirmed by `help@loops.so`
2026-08-03. This closes the hole that made deletion worth questioning: a user who
complains, deletes their account, and re-registers arrives with the **same email
address** and is therefore still suppressed, even though their `userId` differs.
Deleting the contact does not hand anyone a way to erase a spam complaint.

Two consequences that do **not** follow the rest of this brief's `userId`-first
rule, and are easy to get wrong:

- **Suppression lookups must use `email`, not `userId`.** The API accepts
  `GET /v1/contacts/suppression?userId=`, but with an email-keyed list that
  lookup has to resolve `userId` → contact → email first, so it is only as
  reliable as the contact record. After a contact is deleted there is nothing
  left to resolve, and a `userId` query would report "not suppressed" for an
  address that is still suppressed. Everything else keys on `userId`; this one
  call does not.
- **Suppression follows the address, not the person.** If a user changes their
  email, the old address stays suppressed and the new one starts clean — which
  is exactly the behaviour the `hard_bounce` row of the reversibility table
  assumes.

One residual, recorded honestly: Loops answered the *keying* question directly
and the *survival* question by implication. Suppression being a separate,
email-keyed store with its own `DELETE` endpoint and its own removal quota makes
it near-certain that `POST /v1/contacts/delete` does not touch it. It cannot be
tested from our side — there is no endpoint that adds an address to the
suppression list, so a suppressed contact cannot be manufactured for a test. If
certainty is ever wanted, it is one more sentence in an open support thread.

---

## Acceptance Criteria

| # | Criterion | Status |
| -- | -- | -- |
| 1 | `docs/designs/cov-48-marketing-architecture.md` merged | This document |
| 2 | Decision 0 answered with a citation, not an assumption | **Done** — `https://loops.so/docs/webhooks`, event list and signing scheme quoted above |
| 3 | All five decisions recorded with a chosen answer and reasoning | **Done** — see mapping below |
| 4 | States what happens when app and Loops disagree, and which side wins | **Done** — the disagreement matrix under Edge Cases |
| 5 | Confirms transactional keeps `addToAudience: false`, and why | **Done** — Compliance |
| 6 | Compliance section: unsubscribe window, physical address, no pre-checked opt-in | **Done** — Compliance |

**Decision mapping (ticket → this doc):** ticket 0 → D0, ticket 1 → D1, ticket 2
(consent capture) → D4, ticket 3 (identity) and ticket 4 (deletion) → D5 jointly;
D3 (one channel, one list, contacts only on opt-in) is additional to the ticket.

## Prototype

None.

---

## Data Model

No new models and no new table. Four columns on `users`, mirroring the
`accepted_terms_at` / `accepted_privacy_at` idiom already established by
`User::Agreements`.

| Column | Type | Purpose |
| -- | -- | -- |
| `marketing_opt_in_at` | `datetime` | When consent was granted |
| `marketing_opt_in_source` | `string` | Where from — `registration`, `settings`, or `loops` |
| `marketing_opt_out_at` | `datetime` | When it ended |
| `marketing_opt_out_reason` | `string` | `user_app`, `user_loops`, `spam_report`, `hard_bounce` |

**State is derived, not stored.** `marketing_subscribed?` is
`marketing_opt_in_at.present? && marketing_opt_out_at.nil?`, with a matching
scope for COV-51's sync. A separate boolean column would be a second source of
truth that can disagree with its own timestamps — precisely the class of bug
this brief exists to prevent.

**Not in `users.preferences`.** That jsonb column exists for UI preferences.
Consent must be queryable for the sync scope and defensible in an audit; both
argue for real columns with real types.

**No stored Loops contact id.** Every call keys on `userId`, which we already
own. Storing Loops' id adds a column that can go stale and buys nothing.

### The reversibility rule

"Terminal" means terminal against *automated* writes, not against the user — a
toggle you can only switch off once is user-hostile. Opt-out reasons therefore
differ in whether the user can clear them:

| Reason | User can re-opt-in? | Why |
| -- | -- | -- |
| `user_app` | Yes | They changed their mind; that is what the toggle is for |
| `user_loops` | Yes | Same act, different surface |
| `hard_bounce` | Only after changing their email address | The address is undeliverable; a new address is a new fact — and Loops' suppression is keyed on the address, so a new one genuinely starts clean (Decision 5) |
| `spam_report` | **No** | They told a mailbox provider we are spam. Re-mailing on the strength of an in-app click is how domain reputation dies |

Because irreversible reasons are never cleared, the columns cannot conflict.
Only reversible reasons are nulled on re-opt-in, and `marketing_opt_in_at` is
overwritten with the new consent date — which is the date that matters for
defensibility.

### Sync trigger points

Five, all enqueued as background jobs, all no-ops unless the user is consented
and `contact_sync_enabled` is true (see Edge Cases):

| Event | Loops call |
| -- | -- |
| Opt-in | `PUT /v1/contacts/update` with `subscribed: true` + mailing-list membership |
| Opt-out | `PUT /v1/contacts/update` with `subscribed: false` |
| Email change | `PUT /v1/contacts/update` keyed on `userId` |
| Name change | `PUT /v1/contacts/update`, **`subscribed` omitted** |
| Account deletion | `POST /v1/contacts/delete` |

Upsert everywhere. Because `PUT /v1/contacts/update` creates when absent,
`POST /v1/contacts/create` is never called and its 409-on-duplicate never needs
handling.

**Gotcha for COV-51:** the deletion job must take `email` / `userId` as plain
string arguments, **not** a GlobalID. The user row is gone by the time the job
runs, and ActiveJob's GlobalID deserialization would raise `RecordNotFound` on
every attempt.

---

## Screens / Flows

### Opt-in at registration

1. User fills in the registration form. A **checkbox, unchecked**, offers Cove
   updates.
2. On successful create, if ticked: `marketing_opt_in_at = Time.current`,
   `marketing_opt_in_source = "registration"`.
3. A background job upserts the Loops contact with `subscribed: true` and
   mailing-list membership.

### Opt-in / opt-out in account settings

1. User opens account settings. A toggle shows current state, sourced from the
   app's own columns — **no API read on page render**.
2. Turning it on sets `marketing_opt_in_at`, source `settings`, and clears any
   reversible opt-out. Turning it off sets `marketing_opt_out_at` with reason
   `user_app`.
3. A background job syncs the corresponding `subscribed` value.
4. If the user is opted out for an irreversible reason, the toggle is disabled
   and the copy explains why — undeliverable address, or a spam report — rather
   than silently refusing to move.

### Unsubscribe from an email footer

1. User clicks unsubscribe in a campaign footer and lands in Loops' preference
   center.
2. Loops stops sending immediately. **This is the moment the unsubscribe is
   honored** — nothing in Cove is on the critical path.
3. Loops fires `contact.unsubscribed` or `contact.mailingList.unsubscribed`.
4. Cove's handler verifies the signature, dedupes on `Webhook-Id`, responds 200,
   and processes asynchronously: `marketing_opt_out_at = eventTime`, reason
   `user_loops`.

### Account deletion

1. User deletes their account through the existing Devise registrations flow.
2. An `after_destroy` hook enqueues a contact-delete job carrying the email and
   `userId` as strings.
3. The Loops contact is deleted.

### The webhook handler (requirements only — COV-52 owns the design)

- Verify the HMAC-SHA256 signature over `"${eventId}.${timestamp}.${rawBodyText}"`.
- **Dedupe on `Webhook-Id`** — confirmed by Loops as the correct idempotency key.
  Retention must exceed the **24-hour retry window** (Decision 0); a week gives
  comfortable margin.
- Respond 200 immediately and process asynchronously.
- Skip CSRF verification.
- Tolerate events for contacts with no matching user — log and drop.

Whether dedupe needs its own table is COV-52's call, not this brief's. What is
**not** optional is that dedupe exists and outlives 24 hours.

---

## Edge Cases

### The disagreement matrix

| App says | Loops says | Winner | Behaviour |
| -- | -- | -- | -- |
| Opted in | Unsubscribed | **Loops** | Webhook mirrors it in as `user_loops`. Until it arrives our state is stale, but Loops refuses to send, so nothing wrong goes out |
| Opted out | Subscribed | **App** | Next sync pushes `subscribed: false` |
| Opted in | No contact | **App** | Upsert recreates it — `PUT /update` handles this with no special case |
| Anything | Contact for an unknown `userId` | **Loops, ignored** | Log and drop: a deleted user, or a manual dashboard add |
| Opted out (`spam_report`) | Resubscribed | **App** | The complaint stands. We do not resubscribe |

**A resubscribe in Loops' preference center (`email.resubscribed`) counts as
consent.** It is a deliberate user action on a page we sent them to, so it opts
them back in with `marketing_opt_in_source = "loops"` — which is why that column
takes three values, not two. The single exception is after a spam report, where
nothing in-app or in-Loops brings them back.

### Staging would write into the production audience

COV-38 Decision 2 flagged that staging contacts land in the production audience.
Working it through here, the mitigation the transactional track relies on does
**not** apply:

> **`perform_deliveries = false` does not stop any of this.** That flag lives in
> `Mail::Message#do_delivery` and only ever gated ActionMailer. Contact
> create / update / delete are plain `LoopsClient` HTTP calls with no
> ActionMailer involvement. They would fire from staging at full strength,
> writing seeded test users into the **production** audience and burning the
> 1,000-contact free-plan cap.

The transactional kill switch protects nothing on the marketing track. This
brief therefore adds a second, independent switch: a **`contact_sync_enabled`**
key in `config/loops.yml` — false in development and staging, true in
production. Same mechanism as COV-37 Decision 3, diff-reviewable in the PR, and
it fails closed. Every sync job checks it before issuing any call.

### Others

- **Webhook down or misconfigured.** App state goes stale; no wrong mail is
  sent, because Loops enforces its own unsubscribe state. An outage under 24
  hours repairs itself via Loops' retry schedule (Decision 0) — only a longer or
  permanent misconfiguration needs COV-52's reconciliation sweep.
- **Opt-in by someone Loops already suppresses.** We would push
  `subscribed: true` and Loops would silently not deliver. A
  `GET /v1/contacts/suppression` check on opt-in — **keyed on email, not
  `userId`** (Decision 5) — would catch it. **Still deferred**, but the
  reasoning is weaker than it first looked and is recorded honestly: the obvious
  source of suppression is a spam complaint, which cannot exist before the first
  campaign. The non-obvious source is a **hard bounce on transactional mail**,
  which Cove already sends. Whether a transactional hard bounce adds the address
  to the suppression list is unconfirmed — it cannot unsubscribe a contact,
  because `addToAudience: false` means no contact exists, but the suppression
  list is a separate, address-keyed store. So the gap is narrow rather than
  impossible. The consequence is mild in either case — a user sees "subscribed"
  and receives nothing — and the fix is one API call whenever it is wanted.
  Trigger for revisiting: the first real campaign, or the first report of a
  subscribed user receiving nothing.
- **409 on duplicate email or `userId`.** Unreachable — we only ever
  `PUT /update`, never `POST /create`.
- **Rate limit.** Contact updates share the 10 req/sec team budget with
  transactional sends (COV-38 Findings). Sync jobs are per-user and low volume;
  COV-52's sweep is the only thing that could saturate it and must be paced.

---

## Compliance

Not legal advice. The statutory specifics below are general knowledge — they are
not sourced from Loops' documentation or the `loops-email-sending-best-practices`
skill, both of which are silent on statute.

- **Unsubscribe is honored effectively immediately.** Loops stops sending the
  moment its own state flips, independent of anything Rails does, so CAN-SPAM's
  ten-business-day window is met with enormous margin. Cove's webhook mirror
  exists for UI honesty, not for legal compliance — worth stating plainly so
  nobody later treats COV-52 as a compliance blocker.
- **A physical postal address is already in the footer.** COV-38 set the company
  name and address in Loops for exactly this reason.
- **No pre-checked opt-in**, anywhere. Both capture points default to off, and
  marketing consent is never bundled into the invitation-accept flow.
- **Marketing mail carries a working unsubscribe.** Loops adds the
  preference-center path to marketing email automatically; MJML emails can use
  the `{unsubscribe_link}` tag.
- **Transactional sends keep `addToAudience: false`** (COV-39, COV-37). Password
  reset recipients consented to a password reset. Silently promoting them into a
  marketing audience would build a list of people who never agreed to be on it —
  and would make every consent record in the four columns above meaningless.
  Consent is per-purpose; this is the single line that keeps the two tracks
  honest.
- **Consent provenance is recorded** — when (`marketing_opt_in_at`) and from
  where (`marketing_opt_in_source`) — which is what a GDPR "record of consent"
  requirement asks for, and what an Option A "Loops is authoritative" design
  would have left outside our own database.
- **Deletion is honored end to end.** The user row and the Loops contact both go
  (Decision 5).

---

## Scope

**In:** this document. Decisions 0–5 resolved with a chosen answer and its
reasoning, a disagreement matrix, and a compliance section.

**Deferred / out:**

- Any code, schema, migration, or Loops configuration — COV-49, COV-50, COV-51,
  COV-52, COV-53.
- Creating the mailing list and audience configuration — COV-53.
- The reconciliation sweep's design — COV-52.
- Campaign or workflow content.
- Anything in the transactional track.
- Double opt-in. Unavailable on the API contact path and not being built
  (Decision 3).
- A pre-opt-in suppression check (Edge Cases).

## Open Questions

1. **Resolved 2026-08-03 — suppression is keyed on email address only, and
   `Webhook-Id` is the correct idempotency key.** `help@loops.so` confirmed
   both. The consequences are folded into Decision 0 (retry schedule, dedupe
   retention) and Decision 5 (email-keyed suppression lookups, and why
   delete-on-deletion does not let anyone erase a spam complaint). The one
   sub-question answered by implication rather than directly — whether
   `POST /v1/contacts/delete` leaves the suppression entry standing — is
   recorded as such in Decision 5.
2. **Which Loops account/team the single webhook endpoint is registered under,
   in practice.** Decision 2 says production. The mechanical step — Settings →
   Webhooks, plus storing the signing secret in
   `config/credentials/production.yml.enc` under `loops.webhook_secret`,
   matching COV-31's pattern — belongs to COV-52.
3. **Whether the mailing list is created before or after COV-49.** COV-53 owns
   list creation; COV-49 owns the consent UI. The list id is needed by COV-51's
   sync, not by the UI, so they can land in either order — but `config/loops.yml`
   needs a `mailing_lists:` key under `shared:` before COV-51 can run.

## More Info

### Support reply — resolved 2026-08-03

`help@loops.so` answered two questions:

1. **"Our suppression list is keyed on email address only."** Applied in
   Decision 5 and in the Edge Cases suppression-check bullet.
2. **"The `Webhook-Id` header is the correct idempotency key. The retry schedule
   is roughly 8 times over 24 hrs (there's exponential backoff + jitter)."**
   Applied in Decision 0 and in the webhook handler requirements.

This is the second time a support email has moved this project's design — the
first was COV-38's, recorded in that brief's Findings. Loops answers concrete
API questions quickly, and both replies contained information absent from the
public documentation. Worth continuing to ask rather than inferring.

- **Existing consent precedent.** `User::Agreements`
  (`lib/jumpstart/app/models/user/agreements.rb`) sets `accepted_terms_at` and
  `accepted_privacy_at` via `after_validation` on `:create` and
  `:invitation_accepted`. The four marketing columns deliberately match this
  shape, and the `:invitation_accepted` context is why Decision 4 could rule on
  the invitation flow without new investigation.
- **Account deletion already exists** — `app/views/devise/registrations/edit.html.erb:72-84`
  renders "Cancel my account" as a `button_to` to `registration_path` with a
  Turbo confirm. COV-51's `after_destroy` hook attaches to this existing flow;
  no new UI is required for Decision 5.
- **`LoopsClient` does not exist yet.** COV-39 builds it
  (`LoopsClient < ApplicationClient`, per COV-37 Decision 2). COV-50 adds the
  contacts, lists, events, and suppression methods this brief depends on. As
  COV-37 §"Does this block the marketing track?" recorded, marketing calls are
  additional methods on the same class — no new client and no new transport
  decision.
- **`config/loops.yml` gains two keys** under `shared:` — `mailing_lists:` (the
  list id, COV-53) and `contact_sync_enabled:` per environment (Edge Cases).
  Neither is a secret. The webhook signing secret **is** a secret and belongs in
  per-environment credentials.
- **Loops runs on Amazon SES us-east-1** and handles bounces, unsubscribes, and
  spam complaints itself (COV-38 Findings). This is why the hard-bounce and
  spam-report events arrive without Cove doing any bounce processing.
- **Free-plan ceilings that bound this design:** 1,000 subscribed contacts, and
  4,000 sends per rolling 30 days shared between marketing and transactional
  (COV-38 Findings, confirmed by `help@loops.so` 2026-07-29). Decision 3's
  "contacts only on opt-in" is partly what keeps the first number workable.
- **Loops' Email Blocklist** (Settings → Account) blocks addresses from being
  added to the audience *or* sent transactional email. It is an account-level
  kill switch operating inside Loops, independent of Rails, and is a second
  layer available if `contact_sync_enabled` is ever misconfigured.
