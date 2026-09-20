> Plan created: docs/plans/cov-76-send-family-plan-status-to-loops.md

> Ticket: COV-76
> Branch: feature/cov-76-send-family-plan-status-to-loops

# Feature: Send family plan status to Loops

## Problem

Lifecycle and marketing emails need to know a family's plan so Free families
can be nudged to upgrade and paying families and testers never are. Loops
contacts currently carry only `email`, `userId`, `subscribed`, and the
"Cove updates" list, with no plan information.

## Approach

Add one new intent, `:plan_status`, to the existing `LoopsContactSynchronizer`
and `LoopsContactSyncJob`. No new job or service class — the intent inherits
the production/config gate (`LoopsContactGate`), the consent re-check at write
time, and `LoopsRetryable`'s backoff.

The payload for the new intent is `email` + `userId` + `planStatus`. It
deliberately omits `subscribed` and `mailingLists`:

- Including `email` means that if Loops lacks the contact (e.g. a sign-up
  race), Loops creates a complete contact rather than rejecting the write.
- Omitting `subscribed`/`mailingLists` means a plan change can never
  re-subscribe someone or alter list membership.

`planStatus` is also added to `subscribed_attributes`, so the existing
`:opt_in` path — and therefore `LoopsContactBackfillJob`, which reuses it —
carries plan status too.

Three triggers fan out to every currently opted-in parent of a family via a
helper that queues one `LoopsContactSyncJob.perform_later(user_id,
"plan_status")` per user (`account.parents.marketing_subscribed`). A family
with no opted-in parents queues nothing.

1. **Subscription changes** — in the `pay_subscription` block in
   `config/initializers/pay.rb`:

   ```ruby
   after_commit :sync_family_plan_status, on: :create
   after_commit :sync_family_plan_status, on: :update,
     if: -> { saved_change_to_status? || saved_change_to_ends_at? }
   ```

   The family is `customer.owner`. Covers subscribing (`premium`), cancelling
   at period end, and Stripe's `customer.subscription.deleted` at period end
   (`free`).

2. **Complimentary Premium** — `Account`, `after_update_commit` guarded by
   `saved_change_to_complimentary_premium?`.

3. **Joining or leaving a family** — `AccountUser`,
   `after_commit on: [:create, :destroy]`, queuing for the moving user only.
   The parent who stays has no plan change.

Opting in needs no new trigger; `planStatus` rides along in the existing
`:opt_in` payload.

**Key property: the job carries only `user_id` and the intent, never a plan
value.** Every run reads `Account#plan_status` live, so retries and
out-of-order runs converge on current state.

### Consent gate differs from opt-in on purpose

The `:opt_in` intent skips users whose `marketing_opt_in_source == "loops"`
(`current_app_opt_in?`), because Loops already knows about them. `:plan_status`
gates on `marketing_subscribed?` alone — otherwise Loops-sourced subscribers
would never receive `planStatus` and upgrade nudges would target them blindly.

### Already in place (no work needed)

- The `planStatus` custom property **already exists in Loops** — created
  during the COV-71 audit via `POST /v1/contacts/properties`
  (`{"name":"planStatus","type":"string"}`), listed as
  `planStatus` / "Plan Status" / string. The ticket's "create the property"
  scope item is done.
- `Account#plan_status` exists (COV-75), returning `"premium"`,
  `"complimentary"`, or `"free"`, with paid Premium winning over
  complimentary.

### Explicitly not doing

COV-75's note about preloading `billable_subscriptions` for `plan_status`.
Nothing here iterates over many accounts — the fan-out is per user, and the
backfill reloads users one at a time by design. One extra query per sync is
acceptable; leave `plan_status` as it is.

## Acceptance Criteria

- An opted-in user's contact gets `planStatus` when they opt in.
- Subscribing sends `premium` for each opted-in parent in the family.
- A canceled subscription reaching its end sends `free`.
- Switching a comp on sends `complimentary`; switching it off sends `free`,
  or `premium` if the family is also subscribed.
- Joining or leaving a family sends the new family's status.
- A parent who hasn't opted in produces no Loops request.
- Nothing is sent outside production or when `contact_sync_enabled` is false.
- Failed Loops calls retry like existing Loops jobs.

Verification is tests only — staging can't send to Loops (production-gated).
The live check belongs to COV-78.

## Prototype

None — backend only, no UI.

## Data Model

No migrations, no new models, no schema changes.

Touched:

- `LoopsContactSynchronizer#sync` — new `:plan_status` branch;
  `subscribed_attributes` gains `planStatus`.
- `LoopsContactSyncJob` — accepts the new intent (no signature change).
- `config/initializers/pay.rb` — subscription callbacks.
- `Account` — `after_update_commit` on `complimentary_premium`.
- `AccountUser` — `after_commit on: [:create, :destroy]`.

## Screens / Flows

No user-visible screens. The flows that trigger a sync:

1. **Sign-up.** User created with the marketing box ticked → `:opt_in` job.
   `AccountUser` created → `:plan_status` job. Both send `free`. Two writes at
   sign-up is deliberate — keeping the trigger rule simple beats a special
   case to suppress the second.
2. **Subscribing / cancelling.** Stripe webhook updates `Pay::Subscription` →
   a job per opted-in parent.
3. **Superadmin toggles comp** in `/admin/accounts` → a job per opted-in
   parent.
4. **Accepting a family invite.** Old `AccountUser` destroyed and new one
   created in one transaction → two jobs for the moving user. Both commit
   after the whole move, so both read the same correct value.
5. **Owner removes a parent.** Row destroyed and a default family created in
   the same transaction → two jobs, same value.

## Edge Cases

| Case | Behaviour |
|---|---|
| Not production, or `contact_sync_enabled: false` | `contact_sync_allowed?` is false, synchronizer no-ops. Jobs still queue in dev/test, matching every existing Loops trigger. |
| Parent hasn't opted in | Never queued (fan-out filters on `marketing_subscribed`), and the synchronizer re-checks at write time, so a consent change between queue and run can't leak a write. |
| User opted out between queue and run | Re-check returns nil. No request. |
| User deleted between queue and run | `LoopsContactSyncJob` already returns early on a missing user. |
| User has no active family at run time | Returns nil, sends nothing. Their next membership change sends the correct value. |
| Account deleted | `before_destroy :cancel_billable_subscriptions!` flips subscription status and queues jobs; those users have no family by run time, so nothing is sent. Contact deletion is handled separately by `LoopsContactDeletionJob`. |
| `past_due` | Still `premium`. The status-change hook fires and re-sends the same value — a no-change write, not a wrong one. No extra trigger needed. |
| Loops 429 / 5xx / timeout | `LoopsRetryable` on the existing job retries with polynomial backoff. |
| Mailing list unconfigured | Not checked for this intent; the plan payload doesn't touch the list. |

## Tests

Tests first, WebMock, fixtures only (hand-written literals, no factories).

- **`test/services/loops_contact_synchronizer_test.rb`** — `:plan_status`
  sends `email`, `userId`, `planStatus` and no `subscribed`/`mailingLists`;
  sends for a Loops-sourced opt-in; no-ops for an opted-out user, a user with
  no family, and outside production / with sync disabled. Plus `:opt_in` now
  carrying `planStatus`.
- **`test/jobs/loops_contact_sync_job_test.rb`** — the new intent reaches the
  synchronizer; missing user is a no-op; `LoopsRetryable` applies.
- **`test/integration/loops_plan_status_sync_test.rb`** (new) — asserts
  enqueued jobs for each real trigger: subscribing sends `premium` for every
  opted-in parent and skips the non-opted-in one; a canceled subscription
  reaching its end sends `free`; comp on sends `complimentary`, comp off sends
  `free`, comp off while subscribed sends `premium`; joining and leaving a
  family sends the new family's status.

Fixtures: additions to `accounts.yml` / `users.yml` / `pay_subscriptions.yml`
for an opted-in parent, a non-opted-in parent, a comped family, and a
subscribed family — reusing existing labels wherever they already cover the
state.

## Scope

**In:** the `:plan_status` intent and payload; `planStatus` in the opt-in
payload (which covers the backfill); the three triggers; tests; a one-line
AGENTS.md decision noting that Loops contacts carry `planStatus` and that this
overrides COV-51's no-plan-info rule.

**Deferred:**

- Preloading `billable_subscriptions` in `plan_status` (no caller needs it).
- Any other contact property — COV-51's exclusion still stands for everything
  except plan status.
- Live production verification (COV-78).
- The dunning/lifecycle sequences in Loops that consume `planStatus`.

## Open Questions

None.

## More Info

- The archived COV-51 design doc keeps its "do not sync plan" wording; this
  ticket supersedes it for plan status only, and the override is recorded in
  AGENTS.md.
- Plan-status values and the Loops property setup are documented in
  `docs/designs/cov-71-monetization-family-audit.md`.
