> Plan created: docs/plans/cov-54-lifecycle-events.md
> Ticket: COV-54
> Branch: feature/cov-54-emit-lifecycle-events-to-loops

# Feature: Emit lifecycle events to Loops

## Problem

Loops workflows are triggered by events. `LoopsClient#send_event` exists
(COV-50, `app/clients/loops_client.rb:72`) but nothing calls it, so every
lifecycle email would have to be a hand-sent campaign. COV-55's welcome
sequence needs a trigger that fires for a **new consenting signup** and not for
an existing user who opts in months later — a distinction no Loops-side trigger
can make on its own.

## Approach

### Why an event is needed at all

A welcome sequence in Loops is a Loop (workflow), and a Loop runs against a
**contact**. COV-48 Decision 3 established that a contact exists only for a user
who opted in, so the sequence structurally cannot reach a non-consenting user.
For a registration where the marketing checkbox was ticked, "user signed up" and
"contact added to the marketing list" are therefore the *same moment* — COV-51's
`after_create_commit` fires one `LoopsContactSyncJob(user, "opt_in")` that sets
`subscribed: true` and adds the list membership in a single upsert. On that
evidence alone COV-55 could trigger on list subscription and this ticket would
have nothing to build.

One case breaks that equivalence, and it is the entire justification for this
ticket:

> A user can join the marketing list at two very different moments — **at
> registration**, or **six months later via the settings toggle**. A
> list-subscription trigger cannot tell them apart. "Welcome to Cove, here's how
> to get started" is correct for the first and wrong for the second.

**This design does not force COV-55's hand.** If the list-subscription trigger
turns out to be sufficient when the workflow is authored, the event is still
there and costs nothing. If the new-signup / late-opt-in distinction matters,
only the event can express it. COV-55 should confirm in the Loops UI that a
list-subscription trigger exists as expected; the design holds either way.

### Naming convention — decided once, recorded here

**`snake_case`, past tense, subject-first.** `user_signed_up`.

- Snake case matches both the app's Ruby idiom and Loops' own documentation.
- Past tense because an event is a fact that already happened.
- Subject-first so the event list in Loops sorts sensibly once there is more
  than one.

Renaming an event after workflows depend on it means editing those workflows in
Loops, which is not version-controlled. Follow this convention for every event
added later.

### The event contract

| | |
|---|---|
| **Event name** | `user_signed_up` |
| **When** | A `User` record is created **and** consent was captured at registration |
| **Fires for** | Consenting new registrations only |
| **Never fires for** | Non-consenting signups; settings-toggle opt-ins by existing users; Loops-side resubscribes (`marketing_opt_in_source == "loops"`) |
| **Identity** | `userId` — `user.id.to_s`. Never `email`. |
| **`eventProperties`** | `signed_up_at` — ISO8601, from `user.created_at` |
| **Idempotency key** | `SHA256("user_signed_up:<user_id>")` |

**Why exactly one property.** Loops timestamps the event itself, so
`signed_up_at` is mildly redundant; its value is surviving into the workflow as
a filterable and renderable variable. One property ships rather than none
because zero makes the contract untestable in any meaningful way. Everything
else considered was rejected on principle:

- **First name / last name are top-level Loops contact fields.** Putting them in
  an event payload is precisely the accidental-contact-mutation trap. If the
  welcome email needs a first name it belongs on the **contact record** via
  COV-51's upsert — see Open Questions, where this is flagged as a gap rather
  than fixed here.
- **Plan / billing state does not exist at signup.** Registration precedes any
  subscription.
- **Account type (personal vs team)** is knowable, but nothing in COV-55 needs
  it, and every property emitted becomes a contract that cannot be cheaply
  retracted.

### Emission path — chain, do not race

`POST /v1/events/send` **creates a contact if none exists**. Enqueuing the event
and the contact upsert as two independent jobs from the same
`after_create_commit` would race them, and when the event wins, Loops creates a
contact carrying no `mailingLists` membership and no `subscribed` value we set.
The welcome workflow would then fire against a half-formed contact, and COV-48's
"the absence of a contact is the evidence nobody was mailed without agreeing"
story is weakened by a contact our own upsert did not create.

The event is therefore enqueued by `LoopsContactSyncJob` **after a successful
`opt_in` sync**, not by the model callback:

```
User created with checkbox ticked
  → after_create_commit                          [existing, User::MarketingConsent:29]
    → LoopsContactSyncJob(id, "opt_in")          [existing]
      → LoopsContactSynchronizer#sync            [existing — the upsert lands first]
      → if registration-sourced:
          LoopsEventJob(id, "user_signed_up")    [new]
            → LoopsEventEmitter#emit             [new]
              → LoopsClient#send_event           [existing, COV-50]
```

**Why a separate job rather than emitting inline at the end of the sync job.**
Both are correct — the upsert is an idempotent `PUT` and the event carries a
stable idempotency key, so a whole-job retry would be safe. A separate job gives
the event its own retry envelope, so a flaky Loops event call does not re-issue
contact writes, and each job stays single-purpose. The cost is one extra file.

**How the sync job identifies a registration:**
`user.marketing_opt_in_source == "registration"`. That value is written only by
`capture_registration_marketing_consent`
(`app/models/user/marketing_consent.rb:75`), and re-opting-in through settings
overwrites it with `"settings"` — a reliable discriminator, not a heuristic.

### Consent and environment gating

**The consent gate is structural rather than a check we remembered to write.**
The only path to the event runs through a successful consenting opt-in sync,
which already returns early unless `current_app_opt_in?(user)` holds. A
non-consenting user never enqueues the sync job at all
(`after_create_commit … if: :current_app_marketing_opt_in?`).

`LoopsEventEmitter` re-checks consent and the environment gate independently
anyway, because a gate that holds only by virtue of its caller is one refactor
away from not holding.

**One switch, not two.** Events reuse COV-51's
`production? && contact_sync_enabled?` gate
(`LoopsContactSynchronizer#contact_sync_allowed?`, keyed on `contact_sync_enabled`
in `config/loops.yml`). No new `events_enabled` key. The relevant caveat is
**not** `queue_adapter = :inline` and **not** `perform_deliveries = false` —
neither touches a plain `LoopsClient` HTTP call. Without the shared gate, staging
would write events into the **production** audience at full strength (COV-48,
"Staging would write into the production audience").

### Not mutating contact state through an event payload

`LoopsClient#send_event` already strips `EVENT_RESERVED_FIELDS` from
`contact_properties` (`app/clients/loops_client.rb:11`), but the real protection
is simpler: **the emitter never passes `contact_properties` or `mailing_lists`
at all.** It passes `event_name`, `user_id`, `event_properties`, and
`idempotency_key`, and nothing else. Contact state is COV-51's business
exclusively.

This makes the requirement testable as an assertion on the outgoing request
body: the JSON contains exactly `userId`, `eventName`, and `eventProperties`.

## Acceptance Criteria

- [ ] `user_signed_up` emits with the expected name and `eventProperties` for a consenting registration
- [ ] No event is emitted for a non-consenting signup
- [ ] No event is emitted for a settings-toggle opt-in by an existing user
- [ ] An `Idempotency-Key` header is present, and a 409 reply is absorbed as success
- [ ] The request body carries no top-level contact fields beyond `userId` — `eventProperties` do not leak into contact state
- [ ] Registration succeeds when the Loops endpoint returns 500 — emission failure does not block the originating request
- [ ] No event is emitted when `contact_sync_enabled` is false
- [ ] The event job is not enqueued when the contact sync fails
- [ ] Event names and property contracts recorded in this document for COV-55 to build against
- [ ] `bin/rails test` passes, output shown
- [ ] `bin/rubocop` clean
- [ ] `git diff` reviewed and reported

## Prototype

None.

## Data Model

**No schema change, no migration, no new config key.** Consent state already
lives in the four `users` columns established by COV-48 and implemented by
`User::MarketingConsent`; `contact_sync_enabled` already exists in
`config/loops.yml`.

New and changed files:

| File | Role |
|---|---|
| `app/services/loops_event_emitter.rb` | **New.** Builds the payload, re-checks consent and the environment gate, calls `LoopsClient#send_event`. Mirrors `LoopsContactSynchronizer`'s shape and its injectable `config:` / `environment:` / `client:` seams. |
| `app/jobs/loops_event_job.rb` | **New.** `include LoopsRetryable`; mirrors `LoopsContactSyncJob`. |
| `app/jobs/loops_contact_sync_job.rb` | **Edited.** Enqueues `LoopsEventJob` after a successful `:opt_in` sync whose `marketing_opt_in_source` is `"registration"`. |

## Screens / Flows

No UI. Three server-side flows:

**Consenting registration.** User ticks the marketing checkbox and submits the
registration form → `User` is created with `marketing_opt_in_at` set and
`marketing_opt_in_source = "registration"` → `after_create_commit` enqueues
`LoopsContactSyncJob(id, "opt_in")` → the contact is upserted with
`subscribed: true` and mailing-list membership → the job enqueues
`LoopsEventJob(id, "user_signed_up")` → `user_signed_up` is emitted against the
now-existing contact → COV-55's workflow fires.

**Non-consenting registration.** No sync job, no contact, no event. Nothing
reaches Loops.

**Settings opt-in by an existing user.** `opt_in` sync runs and the contact
joins the list, but `marketing_opt_in_source` is `"settings"`, so no event is
enqueued and the welcome sequence does not fire. This is the case the ticket
exists for.

## Edge Cases

| Case | Behaviour |
|---|---|
| Non-consenting signup | No sync job, no event |
| Settings opt-in months later | Sync runs, source is `"settings"`, no event |
| Loops-side resubscribe (`source == "loops"`) | Excluded upstream by `current_app_opt_in?`. No sync, no event |
| Contact upsert fails | `LoopsContactSyncJob` raises and is retried by `LoopsRetryable`; the event job is never enqueued, because enqueue happens only after `sync` returns successfully. No event against a contact that does not exist |
| Event send fails | Retried with backoff via `LoopsRetryable`. Exhausted retries lose the welcome sequence for that user, silently — see Open Questions |
| Replayed event after a retry that actually succeeded | Same idempotency key → Loops 409 → `LoopsClient#send_event` rescues `Conflict` and returns `true` (`app/clients/loops_client.rb:82`). Success, not error |
| Emission blocking the request | Impossible by construction — the request path ends at `after_create_commit`, two `perform_later` hops from any HTTP call |
| Dev / test / staging | Gate returns early; no HTTP. Test env sets `contact_sync_enabled: false`, so emission tests must stub the config the way `LoopsContactSynchronizer`'s tests already do |

## Scope

**In:**

- `LoopsEventEmitter` service and `LoopsEventJob`
- One event, `user_signed_up`, chained off a successful registration-sourced `opt_in` contact sync
- Consent gating and environment gating, reusing COV-51's single switch
- Idempotency key on every emission
- TDD with WebMock stubs against `https://app.loops.so/api/v1/events/send`

**Deferred:**

- **The workflows that consume the event** — COV-55, authored in Loops.
- **Campaign sends** — COV-56.
- **Billing events** (`trial_started`, `subscribed`, `churned`). These are the
  most valuable lifecycle triggers, and they are deliberately not built. COV-45
  already wires all seven Pay webhook triggers to Loops transactional templates,
  so emitting the same moments as events means one Stripe webhook can produce
  two emails — a transactional receipt and a workflow-triggered lifecycle mail —
  and nothing in the app prevents it. Revisit when a workflow genuinely needs
  one **and** the overlap with the existing transactional template has been
  resolved, not before.
- **Any other event.** Cove has no product-specific domain models yet
  (`app/models/` is Jumpstart's `user` and `account`), so there is no "first
  meaningful action" to instrument. Anything else would be speculative, and
  every event emitted becomes a thing workflows depend on and a thing we cannot
  easily remove.
- **Sending the contact's name to Loops** — see Open Questions.
- **Dead-letter handling for exhausted retries** — see Open Questions.

## Open Questions

1. **The contact record carries no name.** `LoopsContactSynchronizer#subscribed_attributes`
   sends `email`, `userId`, `subscribed`, and `mailingLists` only. If COV-55's
   welcome email personalises on first name, that must come from the **contact
   record**, not from `eventProperties` — putting it in an event payload is the
   contact-mutation trap this design exists to avoid. It is roughly a one-line
   change to COV-51's synchronizer, but it is COV-51's surface and COV-55's
   requirement to state. Flagged, not built.
2. **An exhausted retry loses the welcome sequence silently.** No dead-letter or
   alerting path exists anywhere in this codebase today, and inventing one here
   would be out of scope. Recorded honestly rather than papered over.
3. **Whether Loops offers a list-subscription workflow trigger** as assumed.
   COV-55 should confirm in the Loops UI. The design holds either way — the
   event is what makes the new-signup / late-opt-in distinction possible, and
   COV-55 picks whichever trigger it needs.

## More Info

- **Loops' 409 idempotency window is roughly 24 hours** (COV-50). Beyond that a
  replayed key would be accepted as a new event. Not a practical concern here:
  `user_signed_up` fires once per user, from `after_create_commit`.
- **Rate limit is 10 requests/second per team**, shared across transactional and
  marketing (COV-37, COV-38). `LoopsClient` already routes marketing calls
  through its `throttler` seam, and `send_event` calls it before posting.
- **`LoopsRetryable`** (`app/jobs/concerns/loops_retryable.rb`) already covers
  `LoopsClient::RateLimit`, `InternalError`, and the network-level timeouts with
  `wait: :polynomially_longer`. `LoopsEventJob` includes it unchanged.
- **`userId` is `User#id` as a plain string** (COV-48 Decision 5), consistent
  with every existing contact call. Passing `email` on an event would let a
  stale address create a duplicate contact.
- **Transactional sends keep `addToAudience: false`** (COV-37, COV-39). Nothing
  in this design changes that, and no event is emitted from any transactional
  path.
